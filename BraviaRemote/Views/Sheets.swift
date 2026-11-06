import AppIntents
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
                    ForEach(AppQuickLaunch.allCases) { shortcut in
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
                Text("Select a search box on the TV so its on‑screen keyboard is showing, then type here, or tap the 🎤 on the iPhone keyboard to dictate.")
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
                Label("YouTube and a few other apps use their own keyboard, which can't be typed into from a phone. In those apps, use the D‑pad on their keyboard or the TV remote's voice button.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

// MARK: - Input picker

struct InputPickerSheet: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var inputs: [TVInput] = []
    @State private var current: String?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if failed || inputs.isEmpty {
                    Text("This TV didn't report its inputs. Use the TV's own input menu instead.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(inputs) { input in
                            Button {
                                vm.switchInput(input)
                                dismiss()
                            } label: {
                                row(for: input)
                            }
                        }
                    } footer: {
                        Text("Names come from the TV. Rename inputs on the TV under Settings › Channels & Inputs › External inputs.")
                    }
                }
                Section {
                    Button {
                        vm.press(.tv)
                        dismiss()
                    } label: {
                        Label("TV (live channels)", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Button {
                        vm.press(.input)
                        dismiss()
                    } label: {
                        Label("Open the TV's input menu", systemImage: "rectangle.on.rectangle")
                    }
                }
            }
            .navigationTitle("Inputs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
            .refreshable { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for input: TVInput) -> some View {
        let isCurrent = input.uri == current
        return HStack(spacing: 14) {
            Image(systemName: input.systemImage)
                .font(.title3)
                .foregroundStyle(isCurrent ? theme.accent : .secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(input.displayName).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if let subtitle = input.subtitle { Text(subtitle) }
                    Text(input.connected ? "Connected" : "Nothing connected")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark").foregroundStyle(theme.accent).fontWeight(.semibold)
            }
        }
        .opacity(input.connected || isCurrent ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func load() async {
        do {
            let result = try await vm.loadInputs()
            inputs = result.inputs
            current = result.current
            failed = false
        } catch {
            failed = true
        }
        loading = false
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HardwareVolumeController.settingKey) private var hardwareVolume = true
    @State private var removing: SavedTV?
    @State private var renaming: SavedTV?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    ThemeGrid()
                }

                Section {
                    ForEach(vm.tvs) { tv in
                        tvRow(tv)
                            .swipeActions {
                                Button("Remove", role: .destructive) { removing = tv }
                                Button("Rename") { newName = tv.name; renaming = tv }.tint(.gray)
                            }
                    }
                    Button {
                        dismiss()
                        vm.beginAddingTV()
                    } label: {
                        Label("Add another TV", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("TVs")
                } footer: {
                    Text("Tap a TV to switch to it. Swipe left to rename or remove it.")
                }

                Section {
                    Toggle(isOn: Binding(get: { vm.lockScreenRemoteEnabled },
                                         set: { vm.setLockScreenRemote($0) })) {
                        Label("Lock Screen remote", systemImage: "lock.iphone")
                    }
                } footer: {
                    Text("Shows power, volume, mute and play/pause on the Lock Screen and in the Dynamic Island.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try saying:").font(.subheadline.weight(.semibold))
                        Text("“Turn off the TV with Bravia Remote”")
                        Text("“Mute the TV with Bravia Remote”")
                        Text("“Switch the TV to HDMI 2 with Bravia Remote”")
                    }
                    .font(.footnote)
                    .padding(.vertical, 2)
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Add the TV Remote and TV Power widgets from the Home Screen, and TV Power / Mute TV controls to Control Center (iOS 18).")
                }

                Section {
                    Toggle(isOn: $hardwareVolume) {
                        Label("iPhone volume buttons", systemImage: "speaker.wave.2.fill")
                    }
                } footer: {
                    Text("While the remote is open, the iPhone's volume buttons change the TV volume. Your iPhone's media volume is kept near the middle.")
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
                    LabeledContent("Version", value: Self.appVersion)
                } footer: {
                    Text("Power‑on from standby needs Settings › Network & Internet › Remote Start turned on.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Remove \(removing?.name ?? "TV")?",
                                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let tv = removing {
                        if vm.tvs.count == 1 { dismiss() }
                        vm.remove(tv.id)
                    }
                    removing = nil
                }
            } message: {
                Text("You'll need to pair it again to control it.")
            }
            .alert("Rename TV",
                   isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Save") {
                    if let tv = renaming { vm.rename(tv.id, to: newName) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
    }

    private func tvRow(_ tv: SavedTV) -> some View {
        let isCurrent = tv.id == vm.currentID
        return Button {
            vm.switchTo(tv.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tv")
                    .font(.title3)
                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tv.name).foregroundStyle(.primary)
                    Text([tv.host, tv.model].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
