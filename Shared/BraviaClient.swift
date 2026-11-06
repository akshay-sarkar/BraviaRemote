import Foundation

enum BraviaError: LocalizedError {
    case invalidHost
    case notPaired
    case wrongPIN
    case wrongPSK
    case remoteControlDisabled
    case http(Int)
    case api(code: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "That doesn't look like a valid IP address."
        case .notPaired: return "Pairing expired. Pair the TV again."
        case .wrongPIN: return "Wrong PIN. Check the code on your TV and try again."
        case .wrongPSK:
            return "The TV rejected that Pre-Shared Key. On the TV set IP control › Authentication to “Normal and Pre-Shared Key” and check the key."
        case .remoteControlDisabled:
            return "The TV refused the request. Turn on Settings › Network & Internet › Remote device settings › Control remotely."
        case .http(let code): return "TV returned HTTP \(code)."
        case .api(let code, let message): return "TV error \(code)\(message.isEmpty ? "" : ": \(message)")."
        case .invalidResponse: return "Unexpected response from the TV."
        }
    }
}

struct TVApp: Identifiable, Hashable {
    let title: String
    let uri: String
    let icon: URL?
    var id: String { uri }
}

/// An external input (HDMI, composite…) as reported by `getCurrentExternalInputsStatus`.
struct TVInput: Identifiable, Hashable {
    let uri: String
    let title: String
    let label: String
    let icon: String?
    let connected: Bool
    var id: String { uri }

    /// The user's custom label (e.g. "PS5") when set, otherwise the port name ("HDMI 2").
    var displayName: String { label.isEmpty ? title : label }
    var subtitle: String? { label.isEmpty ? nil : title }

    var systemImage: String {
        let kind = "\(uri) \(icon ?? "")".lowercased()
        if kind.contains("hdmi") { return "cable.connector.horizontal" }
        if kind.contains("composite") || kind.contains("component") { return "cable.coaxial" }
        if kind.contains("scart") { return "cable.connector" }
        return "rectangle.on.rectangle"
    }
}

struct TVInfo {
    let model: String?
    let name: String?
    let mac: String?
}

/// Talks to a Sony BRAVIA (2021 "VH21" Google TV platform and other REST-capable models)
/// over the local network using the Sony REST API + IRCC (SOAP) endpoints.
///
/// Auth: PIN pairing via `/sony/accessControl` `actRegister`. The TV answers the first
/// request with 401 and shows a 4-digit PIN; repeating it with `Authorization: Basic base64(":PIN")`
/// returns an `auth` cookie (~14 days). The PIN stays valid for this client id, so the client
/// silently re-registers when the cookie expires.
@MainActor
final class BraviaClient {
    /// Keychain item names, scoped per TV so several TVs can stay paired at once.
    private struct Keys {
        let cookie: String
        let pin: String
        let psk: String

        init(scope: String) {
            cookie = "auth.cookie.\(scope)"
            pin = "auth.pin.\(scope)"
            psk = "auth.psk.\(scope)"
        }
    }

    var host: String
    var clientId: String
    let nickname: String
    private let keys: Keys

    private(set) var authCookie: String?
    private(set) var pin: String?
    private(set) var psk: String?
    private var requestId = 0
    private var pairing: PairingConnection?
    private let session: URLSession

    var hasCredentials: Bool { authCookie != nil || pin != nil || psk != nil }

    init(host: String, clientId: String, nickname: String, credentialScope: String) {
        self.host = host
        self.clientId = clientId
        self.nickname = nickname
        let keys = Keys(scope: credentialScope)
        self.keys = keys
        self.authCookie = KeychainStore.get(keys.cookie)
        self.pin = KeychainStore.get(keys.pin)
        self.psk = KeychainStore.get(keys.psk)

        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 5
        config.waitsForConnectivity = false
        config.urlCredentialStorage = nil
        config.httpMaximumConnectionsPerHost = 1
        self.session = URLSession(configuration: config, delegate: NoAutoAuthDelegate(), delegateQueue: nil)
    }

    // MARK: - Pairing

    /// Step 1: ask the TV to show a PIN. Returns `false` if the TV authorised us without a PIN.
    ///
    /// Pairing uses a raw curl-style HTTP request instead of URLSession. With URLSession, the TV
    /// showed "Registration cancelled" a second after showing the PIN, while the same request
    /// from curl kept the PIN on screen.
    func requestPIN() async throws -> Bool {
        pairing?.close()
        let connection = PairingConnection(host: host.trimmingCharacters(in: .whitespacesAndNewlines))
        pairing = connection
        let response = try await connection.post(path: "/sony/accessControl",
                                                 body: registerBody(),
                                                 headers: ["Content-Type": "application/json; charset=UTF-8"])
        switch response.status {
        case 401: return true // PIN is on screen
        case 200:
            closePairing()
            if let cookie = Self.extractAuthCookie(fromSetCookie: response.headers["set-cookie"]) {
                store(cookie: cookie, pin: pin)
            }
            return false
        case 403:
            closePairing()
            throw BraviaError.remoteControlDisabled
        default:
            closePairing()
            throw BraviaError.http(response.status)
        }
    }

    /// Step 2: send the PIN shown on screen and receive the auth cookie.
    func confirmPIN(_ pin: String) async throws {
        let token = Data(":\(pin)".utf8).base64EncodedString()
        let connection = pairing ?? PairingConnection(host: host.trimmingCharacters(in: .whitespacesAndNewlines))
        pairing = connection
        defer { closePairing() }
        let response = try await connection.post(path: "/sony/accessControl",
                                                 body: registerBody(),
                                                 headers: ["Content-Type": "application/json; charset=UTF-8",
                                                           "Authorization": "Basic \(token)"])
        switch response.status {
        case 200:
            guard let cookie = Self.extractAuthCookie(fromSetCookie: response.headers["set-cookie"]) else {
                throw BraviaError.invalidResponse
            }
            store(cookie: cookie, pin: pin)
        case 401: throw BraviaError.wrongPIN
        case 403: throw BraviaError.remoteControlDisabled
        default: throw BraviaError.http(response.status)
        }
    }

    private func closePairing() {
        pairing?.close()
        pairing = nil
    }

    /// Alternative to PIN pairing: the TV's IP-control Pre-Shared Key, sent as `X-Auth-PSK` on every request.
    /// Validated with a call that requires authentication.
    func usePSK(_ key: String) async throws {
        store(cookie: nil, pin: nil)
        psk = key
        do {
            _ = try await call("appControl", "getApplicationList", allowRenew: false)
            KeychainStore.set(key, for: keys.psk)
        } catch BraviaError.notPaired {
            psk = nil
            throw BraviaError.wrongPSK
        } catch {
            psk = nil
            throw error
        }
    }

    func forget() {
        store(cookie: nil, pin: nil)
        psk = nil
        KeychainStore.set(nil, for: keys.psk)
    }

    /// Re-registers with the saved PIN. Returns false if the TV no longer accepts it.
    /// Network errors are rethrown so a TV that's just unreachable doesn't wipe pairing.
    private func renewAuth() async throws -> Bool {
        guard let pin else { return false }
        do {
            try await confirmPIN(pin)
            return true
        } catch let error as BraviaError {
            switch error {
            case .wrongPIN, .remoteControlDisabled, .invalidResponse: return false
            default: throw error
            }
        }
    }

    private func store(cookie: String?, pin: String?) {
        authCookie = cookie
        self.pin = pin
        KeychainStore.set(cookie, for: keys.cookie)
        KeychainStore.set(pin, for: keys.pin)
    }

    private func registerBody() -> Data {
        let payload: [String: Any] = [
            "method": "actRegister",
            "id": 8,
            "version": "1.0",
            "params": [
                ["clientid": clientId, "nickname": nickname, "level": "private"],
                [["value": "yes", "function": "WOL"]]
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    // MARK: - IRCC (remote buttons)

    func send(code: String, allowRenew: Bool = true) async throws {
        let envelope = """
        <?xml version="1.0"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1"><IRCCCode>\(code)</IRCCCode></u:X_SendIRCC></s:Body>\
        </s:Envelope>
        """
        let (_, http) = try await post(path: "IRCC",
                                       body: Data(envelope.utf8),
                                       headers: ["Content-Type": "text/xml; charset=UTF-8",
                                                 "SOAPACTION": "\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\""],
                                       timeout: 3)
        switch http.statusCode {
        case 200: return
        case 401, 403:
            if allowRenew, try await renewAuth() {
                try await send(code: code, allowRenew: false)
                return
            }
            throw BraviaError.notPaired
        default:
            throw BraviaError.http(http.statusCode)
        }
    }

    // MARK: - JSON-RPC services

    /// Returns the TV's own IRCC code table, keyed by button name.
    func remoteControllerCodes() async throws -> [String: String] {
        let result = try await call("system", "getRemoteControllerInfo")
        guard result.count > 1, let list = result[1] as? [[String: Any]] else { return [:] }
        var codes: [String: String] = [:]
        for item in list {
            if let name = item["name"] as? String, let value = item["value"] as? String {
                codes[name] = value
            }
        }
        return codes
    }

    func isPoweredOn() async throws -> Bool {
        let result = try await call("system", "getPowerStatus")
        return (result.first as? [String: Any])?["status"] as? String == "active"
    }

    /// Needs "Remote Start" enabled on the TV to work from standby.
    func setPower(_ on: Bool) async throws {
        try await call("system", "setPowerStatus", params: [["status": on]])
    }

    /// - Parameter allowRenew: false when probing a TV that might not be ours (auto-reconnect),
    ///   so a saved PIN is never sent to a different TV.
    func systemInfo(allowRenew: Bool = true) async throws -> TVInfo {
        let result = try await call("system", "getSystemInformation", allowRenew: allowRenew)
        let info = result.first as? [String: Any] ?? [:]
        return TVInfo(model: info["model"] as? String,
                      name: info["name"] as? String,
                      mac: info["macAddr"] as? String)
    }

    func applications() async throws -> [TVApp] {
        let result = try await call("appControl", "getApplicationList")
        guard let list = result.first as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let title = item["title"] as? String, let uri = item["uri"] as? String else { return nil }
            let icon = (item["icon"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            return TVApp(title: title, uri: uri, icon: icon)
        }
    }

    func launch(uri: String) async throws {
        try await call("appControl", "setActiveApp", params: [["uri": uri]])
    }

    /// HDMI and other external inputs, with any custom labels set on the TV.
    func externalInputs() async throws -> [TVInput] {
        let result = try await call("avContent", "getCurrentExternalInputsStatus")
        guard let list = result.first as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let uri = item["uri"] as? String else { return nil }
            let connected: Bool
            if let flag = item["connection"] as? Bool { connected = flag }
            else { connected = (item["status"] as? String) == "true" }
            return TVInput(uri: uri,
                           title: item["title"] as? String ?? uri,
                           label: item["label"] as? String ?? "",
                           icon: item["icon"] as? String,
                           connected: connected)
        }
    }

    /// URI of what's on screen now (an input or a channel), or nil while an app is showing.
    func playingContentURI() async -> String? {
        guard let result = try? await call("avContent", "getPlayingContentInfo") else { return nil }
        return (result.first as? [String: Any])?["uri"] as? String
    }

    func switchInput(uri: String) async throws {
        try await call("avContent", "setPlayContent", params: [["uri": uri]])
    }

    /// Types into the TV's on-screen keyboard (a text field must be focused on the TV).
    func sendText(_ text: String) async throws {
        try await call("appControl", "setTextForm", params: [text])
    }

    @discardableResult
    func call(_ service: String,
              _ method: String,
              params: [Any] = [],
              version: String = "1.0",
              allowRenew: Bool = true) async throws -> [Any] {
        requestId += 1
        let payload: [String: Any] = ["method": method, "params": params, "id": requestId, "version": version]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await post(path: service, body: body, headers: ["Content-Type": "application/json"])

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let errorInfo = json?["error"] as? [Any]
        let errorCode = errorInfo?.first as? Int
        let authFailed = http.statusCode == 401 || http.statusCode == 403 || errorCode == 401 || errorCode == 403

        if authFailed {
            if allowRenew, try await renewAuth() {
                return try await call(service, method, params: params, version: version, allowRenew: false)
            }
            throw BraviaError.notPaired
        }
        guard http.statusCode == 200 else { throw BraviaError.http(http.statusCode) }
        if let errorInfo {
            let message = errorInfo.count > 1 ? (errorInfo[1] as? String ?? "") : ""
            throw BraviaError.api(code: errorCode ?? -1, message: message)
        }
        return json?["result"] as? [Any] ?? []
    }

    // MARK: - HTTP

    private func post(path: String,
                      body: Data,
                      headers: [String: String],
                      sendCookie: Bool = true,
                      timeout: TimeInterval = 5) async throws -> (Data, HTTPURLResponse) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: "http://\(trimmed)/sony/\(path)") else {
            throw BraviaError.invalidHost
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = body
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        if sendCookie, let authCookie { request.setValue("auth=\(authCookie)", forHTTPHeaderField: "Cookie") }
        if let psk { request.setValue(psk, forHTTPHeaderField: "X-Auth-PSK") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BraviaError.invalidResponse }
        return (data, http)
    }

    private static func extractAuthCookie(fromSetCookie raw: String?) -> String? {
        guard let raw, let range = raw.range(of: "auth=") else { return nil }
        let value = raw[range.upperBound...].prefix { $0 != ";" && $0 != "\n" && $0 != "," }
        return value.isEmpty ? nil : String(value)
    }
}

/// The TV answers the PIN request with `401 WWW-Authenticate: Basic`. URLSession must hand that
/// 401 straight back to us. It must not answer the challenge itself, because a second
/// request reaching the TV closes the PIN pop-up.
private final class NoAutoAuthDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodDefault:
            completionHandler(.rejectProtectionSpace, nil)
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
