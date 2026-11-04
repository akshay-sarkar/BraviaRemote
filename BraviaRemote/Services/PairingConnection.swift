import Foundation
import Network

/// Minimal HTTP/1.1 client used only for PIN pairing. It behaves like `curl`, which was
/// confirmed to keep the TV's PIN on screen. Each request gets its own TCP connection. The
/// client sends exactly the bytes we write (no automatic auth handling, no retries), reads one
/// response and closes the connection.
final class PairingConnection {
    struct Response {
        let status: Int
        /// Lower-cased header names. Repeated headers (e.g. Set-Cookie) are joined with "\n".
        let headers: [String: String]
        let body: Data
    }

    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "BraviaRemote.pairing")
    private var connection: NWConnection?

    init(host: String, port: UInt16 = 80) {
        self.host = host
        self.port = port
    }

    deinit { connection?.cancel() }

    func close() {
        connection?.cancel()
        connection = nil
    }

    func post(path: String, body: Data, headers: [String: String]) async throws -> Response {
        let conn = try await openIfNeeded()

        var head = "POST \(path) HTTP/1.1\r\n"
        head += "Host: \(host)\r\n"
        head += "User-Agent: BraviaRemote/1.0\r\n"
        head += "Accept: */*\r\n"
        head += "Content-Length: \(body.count)\r\n"
        for (name, value) in headers { head += "\(name): \(value)\r\n" }
        head += "\r\n"
        var request = Data(head.utf8)
        request.append(body)

        // Cancelling the connection makes any pending receive fail, which acts as a timeout.
        let timeout = DispatchWorkItem { conn.cancel() }
        queue.asyncAfter(deadline: .now() + 8, execute: timeout)
        defer { timeout.cancel() }

        do {
            try await send(request, on: conn)
            let response = try await readResponse(on: conn)
            close() // one request per connection, exactly like curl
            return response
        } catch {
            close()
            throw (error as? URLError) ?? URLError(.networkConnectionLost)
        }
    }

    // MARK: - Connection

    private func openIfNeeded() async throws -> NWConnection {
        if let connection, connection.state == .ready { return connection }
        connection?.cancel()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw URLError(.badURL) }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection = conn

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = OnceGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.claim() { continuation.resume() }
                case .failed:
                    if gate.claim() { continuation.resume(throwing: URLError(.cannotConnectToHost)) }
                case .cancelled:
                    if gate.claim() { continuation.resume(throwing: URLError(.cancelled)) }
                default:
                    break // .waiting happens while iOS asks for Local Network permission
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 20) {
                if gate.claim() {
                    conn.cancel()
                    continuation.resume(throwing: URLError(.timedOut))
                }
            }
        }
        return conn
    }

    private func send(_ data: Data, on conn: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    /// Returns the next bytes from the socket, or nil when the peer closed the connection.
    private func receive(on conn: NWConnection) async throws -> Data? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    // MARK: - HTTP parsing

    private func readResponse(on conn: NWConnection) async throws -> Response {
        var buffer = Data()
        let separator = Data("\r\n\r\n".utf8)

        // Head
        var headEnd: Range<Data.Index>?
        while headEnd == nil {
            guard let chunk = try await receive(on: conn) else { throw URLError(.networkConnectionLost) }
            buffer.append(chunk)
            headEnd = buffer.range(of: separator)
        }
        guard let headRange = headEnd else { throw URLError(.cannotParseResponse) }
        let headText = String(decoding: buffer[buffer.startIndex..<headRange.lowerBound], as: UTF8.self)
        var rest = Data(buffer[headRange.upperBound...])

        var lines = headText.components(separatedBy: "\r\n")
        let statusLine = lines.removeFirst()
        let statusParts = statusLine.split(separator: " ")
        guard statusParts.count >= 2, let status = Int(statusParts[1]) else {
            throw URLError(.cannotParseResponse)
        }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = headers[name].map { "\($0)\n\(value)" } ?? value
        }

        // Body
        var body = Data()
        if let lengthText = headers["content-length"], let length = Int(lengthText) {
            while rest.count < length {
                guard let chunk = try await receive(on: conn) else { break }
                rest.append(chunk)
            }
            body = Data(rest.prefix(length))
        } else if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            body = try await readChunked(initial: rest, on: conn)
        } else if status != 401 && status != 204 && status != 304 {
            // No length given: the body runs until the TV closes the connection.
            while let chunk = try await receive(on: conn) { rest.append(chunk) }
            body = rest
            close()
        }
        return Response(status: status, headers: headers, body: body)
    }

    private func readChunked(initial: Data, on conn: NWConnection) async throws -> Data {
        var buffer = initial
        var body = Data()
        let crlf = Data("\r\n".utf8)

        func fill(until condition: (Data) -> Bool) async throws {
            while !condition(buffer) {
                guard let chunk = try await receive(on: conn) else { throw URLError(.networkConnectionLost) }
                buffer.append(chunk)
            }
        }

        while true {
            try await fill { $0.range(of: crlf) != nil }
            guard let lineEnd = buffer.range(of: crlf) else { throw URLError(.cannotParseResponse) }
            let sizeText = String(decoding: buffer[buffer.startIndex..<lineEnd.lowerBound], as: UTF8.self)
                .split(separator: ";").first.map(String.init) ?? ""
            guard let size = Int(sizeText.trimmingCharacters(in: .whitespaces), radix: 16) else {
                throw URLError(.cannotParseResponse)
            }
            buffer = Data(buffer[lineEnd.upperBound...])
            if size == 0 { break }
            try await fill { $0.count >= size + 2 }
            body.append(buffer.prefix(size))
            buffer = Data(buffer.dropFirst(size + 2))
        }
        return body
    }
}

/// Lets exactly one of several racing callbacks resume a continuation.
private final class OnceGate {
    private var done = false
    private let lock = NSLock()

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
