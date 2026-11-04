import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @StateObject private var discovery = TVDiscovery()

    enum AuthMethod: String, CaseIterable, Identifiable {
        case pin = "PIN code"
        case psk = "Pre-Shared Key"
        var id: String { rawValue }
    }

    @State private var host = ""
    @State private var selectedName: String?
    @State private var method: AuthMethod = .pin
    @State private var psk = ""
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
                    noPinSection
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
                    Task { await select(tv) }
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
                .onSubmit { Task { await connect() } }

            Picker("Sign in with", selection: $method) {
                ForEach(AuthMethod.allCases) { Text($0.rawValue).tag($0) }
            }

            if method == .psk {
                SecureField("Pre-Shared Key (e.g. 0000)", text: $psk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await connect() } }
            }

            Button("Connect") { Task { await connect() } }
                .disabled(host.isEmpty || (method == .psk && psk.isEmpty))
        } header: {
            Text("TV IP address")
        } footer: {
            Text(method == .pin
                 ? "On the TV: Settings › Network & Internet › your network shows the IP address."
                 : "On the TV: Settings › Network & Internet › Home network › IP control › Authentication = “Normal and Pre-Shared Key”, then set the Pre-Shared Key.")
        }
    }

    private var howToSection: some View {
        Section("Before you start") {
            step(1, "Turn the TV on (not standby).")
            step(2, "On the TV open Settings › Network & Internet › Remote device settings and turn on Control remotely.")
            step(3, "Optional: turn on Remote Start so the app can switch the TV on.")
            step(4, "Keep your iPhone on the same Wi‑Fi as the TV, and allow Local Network access when iOS asks.")
        }
    }

    private var pinSection: some View {
        Section {
            Text("A 4‑digit PIN should now be showing on your TV.")
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

    private var noPinSection: some View {
        Section {
            step(1, "Make sure the TV is on and showing a picture, then tap Show a new PIN.")
            step(2, "Check Settings › Network & Internet › Remote device settings › Control remotely is on.")
            step(3, "Open Remote device settings › Deregister remote device, remove old “Bravia Remote” entries, then try again.")
            step(4, "If IP control › Authentication is set to “Pre-Shared Key” only, the TV never shows a PIN. Use a Pre-Shared Key instead.")
            Button("Use Pre-Shared Key instead") {
                method = .psk
                awaitingPIN = false
                pin = ""
                error = nil
            }
        } header: {
            Text("No PIN on the TV?")
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

    private func select(_ tv: DiscoveredTV) async {
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
        if method == .psk && psk.isEmpty {
            error = "Enter the Pre-Shared Key, then tap Connect."
            return
        }
        await connect()
    }

    private func connect() async {
        switch method {
        case .pin: await requestPIN()
        case .psk: await connectWithPSK()
        }
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

    private func connectWithPSK() async {
        guard !psk.isEmpty else { return }
        error = nil
        working = true
        defer { working = false }
        do {
            try await vm.pair(host: host, psk: psk, name: selectedName)
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
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return "Couldn't reach the TV. Check the IP, that the TV is on, and that iOS Settings › Bravia Remote › Local Network is on."
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
