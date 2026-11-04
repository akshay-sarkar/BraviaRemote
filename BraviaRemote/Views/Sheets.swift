import SwiftUI

// MARK: - Apps

struct AppsView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    private var filtered: [TVApp] {
        query.isEmpty ? vm.apps : vm.apps.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(spacing: 8) {
                    ForEach(AppShortcut.allCases) { shortcut in
                        quickLaunch(shortcut.rawValue) { vm.open(shortcut) }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if loading && vm.apps.isEmpty {
                    ProgressView().padding(40)
                } else if vm.apps.isEmpty {
                    ContentUnavailableView("No apps",
                                           systemImage: "square.grid.2x2",
                                           description: Text("Turn the TV on and try again."))
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(filtered) { app in
                            Button {
                                vm.launch(app)
                                dismiss()
                            } label: {
                                AppTile(app: app)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .searchable(text: $query, prompt: "Search apps")
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await vm.loadApps()
                loading = false
            }
            .refreshable { await vm.loadApps() }
        }
        .presentationDragIndicator(.visible)
    }

    private func quickLaunch(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            AppKey(title: title)
        }
        .buttonStyle(.plain)
    }
}

private struct AppTile: View {
    let app: TVApp

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: app.icon) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Text(String(app.title.prefix(1)))
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.1))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(app.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32, alignment: .top)
        }
    }
}

// MARK: - Keyboard

struct KeyboardSheet: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a search box on the TV first, then type — or tap the 🎤 on the iPhone keyboard to dictate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Type to send to TV", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($focused)
                    .submitLabel(.send)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(send)

                HStack {
                    Button("Send", action: send)
                        .buttonStyle(.borderedProminent)
                        .disabled(text.isEmpty)
                    Button("Clear on TV") { vm.sendText("") }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button { vm.press(.back) } label: { Label("Back", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Voice & Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(260), .medium])
    }

    private func send() {
        guard !text.isEmpty else { return }
        vm.sendText(text)
        vm.press(.confirm)
    }
}

// MARK: - Number pad

struct NumberPadSheet: View {
    @EnvironmentObject private var vm: RemoteViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...9, id: \.self) { n in digit(n) }
                RemoteButton("Guide", action: { vm.press(.guide) }) {
                    KeyCap(systemImage: "list.bullet.rectangle", size: 64)
                }
                digit(0)
                RemoteButton("Info", action: { vm.press(.display) }) {
                    KeyCap(systemImage: "info", size: 64)
                }
            }
            HStack(spacing: 14) {
                colorKey(.red, .red)
                colorKey(.green, .green)
                colorKey(.yellow, .yellow)
                colorKey(.blue, .blue)
            }
        }
        .padding(28)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func digit(_ n: Int) -> some View {
        RemoteButton("\(n)", action: { vm.press(.number(n)) }) {
            Text("\(n)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.key))
                .overlay(Circle().stroke(Theme.keyStroke, lineWidth: 1))
        }
    }

    private func colorKey(_ key: RemoteKey, _ color: Color) -> some View {
        RemoteButton(key.rawValue, action: { vm.press(key) }) {
            Capsule()
                .fill(color.opacity(0.85))
                .frame(width: 58, height: 22)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    ThemeGrid()
                }
                Section("TV") {
                    LabeledContent("Name", value: vm.tvName)
                    LabeledContent("IP address", value: vm.host)
                    if let model = vm.tvModel { LabeledContent("Model", value: model) }
                }
                Section("Extra keys (not on the physical remote)") {
                    Button("Rewind") { vm.press(.rewind) }
                    Button("Fast forward") { vm.press(.forward) }
                    Button("Stop") { vm.press(.stop) }
                    Button("Previous track") { vm.press(.prev) }
                    Button("Next track") { vm.press(.next) }
                    Button("Subtitles") { vm.press(.subtitle) }
                    Button("Info / Display") { vm.press(.display) }
                    Button("Options") { vm.press(.options) }
                }
                Section {
                    Button("Forget this TV", role: .destructive) { confirmForget = true }
                } footer: {
                    Text("Power‑on from standby needs Settings › Network & Internet › Remote Start turned on.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Forget \(vm.tvName)?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("Forget", role: .destructive) {
                    dismiss()
                    vm.forgetTV()
                }
            } message: {
                Text("You'll need to pair again with a PIN.")
            }
        }
    }
}
