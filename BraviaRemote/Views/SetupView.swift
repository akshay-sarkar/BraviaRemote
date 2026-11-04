import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @StateObject private var discovery = TVDiscovery()

    @State private var host = ""
    @State private var selectedName: String?
    @State private var pin = ""
    @State private var awaitingPIN = false
    @State private var working = false
    @State private var error: String?
    @FocusState private var pinFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if awaitingPIN {
                    pinSection
                } else {
                    discoverySection
                    manualSection
                    howToSection
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(awaitingPIN ? "Enter PIN" : "Connect your BRAVIA")
            .toolbar {
                if awaitingPIN {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            awaitingPIN = false
                            pin = ""
                            error = nil
                        }
                    }
                }
            }
            .disabled(working)
            .overlay { if working { ProgressView().controlSize(.large) } }
            .onAppear { discovery.start() }
            .onDisappear { discovery.stop() }
        }
    }

    // MARK: - Sections

    private var discoverySection: some View {
        Section {
            if discovery.tvs.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching your Wi‑Fi…").foregroundStyle(.secondary)
                }
            }
            ForEach(discovery.tvs) { tv in
                Button {
                    Task { await connect(to: tv) }
                } label: {
                    HStack {
                        Image(systemName: "tv")
                            .foregroundStyle(tv.looksLikeBravia ? Color.accentColor : .secondary)
                        VStack(alignment: .leading) {
                            Text(tv.name).foregroundStyle(.primary)
                            if let model = tv.model {
                                Text(model).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Found on your network")
        }
    }

    private var manualSection: some View {
        Section {
            TextField("e.g. 192.168.1.50", text: $host)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { Task { await requestPIN() } }
            Button("Connect") { Task { await requestPIN() } }
                .disabled(host.isEmpty)
        } header: {
            Text("Or enter the TV's IP address")
        } footer: {
            Text("On the TV: Settings › Network & Internet › your network › IP address.")
        }
    }

    private var howToSection: some View {
        Section("Before you start") {
            step(1, "On the TV open Settings › Network & Internet › Remote device settings.")
            step(2, "Turn on Control remotely. Set Authentication to Normal (PIN).")
            step(3, "Optional: turn on Remote Start so the app can switch the TV on.")
            step(4, "Keep your iPhone on the same Wi‑Fi as the TV.")
        }
    }

    private var pinSection: some View {
        Section {
            Text("A 4‑digit PIN is showing on your TV.")
                .font(.subheadline)
            TextField("PIN", text: $pin)
                .keyboardType(.numberPad)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .focused($pinFocused)
                .onChange(of: pin) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(4))
                    if digits != newValue { pin = digits }
                    if digits.count == 4 { Task { await submitPIN() } }
                }
            Button("Pair") { Task { await submitPIN() } }
                .disabled(pin.count != 4)
            Button("Show a new PIN") { Task { await requestPIN() } }
        } footer: {
            Text("Pairing with \(selectedName ?? host)")
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.25)))
            Text(text).font(.footnote)
        }
    }

    // MARK: - Actions

    private func connect(to tv: DiscoveredTV) async {
        error = nil
        working = true
        let ip = await discovery.resolveIPv4(tv)
        working = false
        guard let ip else {
            error = "Couldn't get the IP address of \(tv.name). Enter it manually below."
            return
        }
        host = ip
        selectedName = tv.name
        await requestPIN()
    }

    private func requestPIN() async {
        error = nil
        working = true
        defer { working = false }
        do {
            let needsPIN = try await vm.requestPIN(host: host, name: selectedName)
            if needsPIN {
                pin = ""
                awaitingPIN = true
                pinFocused = true
            }
        } catch {
            self.error = Self.describe(error)
        }
    }

    private func submitPIN() async {
        guard pin.count == 4, !working else { return }
        error = nil
        working = true
        defer { working = false }
        do {
            try await vm.pair(pin: pin)
        } catch {
            self.error = Self.describe(error)
            pin = ""
        }
    }

    private static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return "Couldn't reach the TV. Check the IP, that it's on, and that Local Network access is allowed for this app in iOS Settings."
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
