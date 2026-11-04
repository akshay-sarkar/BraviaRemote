import Foundation
import Network

struct DiscoveredTV: Identifiable, Hashable {
    let id: String
    let name: String
    let model: String?
    let endpoint: NWEndpoint

    var looksLikeBravia: Bool {
        let text = "\(name) \(model ?? "")".lowercased()
        return text.contains("bravia") || text.contains("sony")
    }
}

/// Finds Google TV based BRAVIAs via Bonjour (`_googlecast._tcp`).
/// Bonjour browsing works without the restricted multicast entitlement (SSDP would need it).
@MainActor
final class TVDiscovery: ObservableObject {
    @Published private(set) var tvs: [DiscoveredTV] = []
    @Published private(set) var isSearching = false

    private var browser: NWBrowser?

    func start() {
        stop()
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_googlecast._tcp", domain: nil),
                                using: parameters)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found: [DiscoveredTV] = results.compactMap { result in
                guard case let .service(serviceName, _, _, _) = result.endpoint else { return nil }
                var name = serviceName
                var model: String?
                if case let .bonjour(txt) = result.metadata {
                    name = txt["fn"] ?? serviceName
                    model = txt["md"]
                }
                return DiscoveredTV(id: serviceName, name: name, model: model, endpoint: result.endpoint)
            }
            let sorted = found.sorted {
                if $0.looksLikeBravia != $1.looksLikeBravia { return $0.looksLikeBravia }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            Task { @MainActor in self?.tvs = sorted }
        }
        browser.stateUpdateHandler = { [weak self] state in
            let searching: Bool
            switch state {
            case .ready, .setup: searching = true
            default: searching = false
            }
            Task { @MainActor in self?.isSearching = searching }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    /// Resolves a Bonjour service to an IPv4 address by opening (and immediately closing) a TCP connection.
    func resolveIPv4(_ tv: DiscoveredTV) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let parameters = NWParameters.tcp
            if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                ip.version = .v4
            }
            let resolver = Resolver(connection: NWConnection(to: tv.endpoint, using: parameters),
                                    continuation: continuation)
            resolver.start()
        }
    }

    /// Resumes the continuation exactly once. All callbacks run on the main queue.
    private final class Resolver {
        private let connection: NWConnection
        private var continuation: CheckedContinuation<String?, Never>?

        init(connection: NWConnection, continuation: CheckedContinuation<String?, Never>) {
            self.connection = connection
            self.continuation = continuation
        }

        func start() {
            connection.stateUpdateHandler = { [self] state in
                switch state {
                case .ready:
                    if case let .hostPort(host, _) = connection.currentPath?.remoteEndpoint {
                        finish(TVDiscovery.ipString(host))
                    } else {
                        finish(nil)
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in finish(nil) }
        }

        private func finish(_ value: String?) {
            guard let continuation else { return }
            self.continuation = nil
            connection.stateUpdateHandler = nil
            connection.cancel()
            continuation.resume(returning: value)
        }
    }

    nonisolated static func ipString(_ host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let address):
            return address.rawValue.map { String($0) }.joined(separator: ".")
        case .name(let name, _):
            return name
        default:
            return nil
        }
    }
}
