import SwiftUI

/// Main screen. Mirrors the physical BRAVIA voice remote (RMF-TX series) key for key, top to bottom:
///
///   [name/status]          [⋯] [⏻]
///   TV                         ⚙︎
///   Input                      123
///          ( D-pad + OK )
///   Back                      Home
///   VOL±     Assistant/Mute    CH±
///   Play       Pause         Guide
///   YouTube           Netflix
///   Disney+           Prime Video
struct RemoteView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case apps, voice, numbers, settings
        var id: String { rawValue }
    }

    /// Natural height of the layout; smaller screens scale the whole remote down to fit.
    private let designHeight: CGFloat = 770

    var body: some View {
        GeometryReader { geo in
            let scale = min(1, geo.size.height / designHeight)
            content
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.vertical, 4)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let toast = vm.toast {
                ToastView(text: toast).padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.toast)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .apps: AppsView()
            case .voice: KeyboardSheet()
            case .numbers: NumberPadSheet()
            case .settings: SettingsView()
            }
        }
        .onAppear { vm.refresh() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            gap
            sideKeys(left: tvKey, right: key(.actionMenu, "Settings") { KeyCap(systemImage: "gearshape.fill") })
            gap
            sideKeys(left: key(.input, "Input") { GlyphKey(shape: InputGlyph()) },
                     right: RemoteButton("Number pad", action: { sheet = .numbers }) { TextKey(text: "123") })
            gap
            DPadView { vm.press($0) }
                .frame(width: 228, height: 228)
            gap
            sideKeys(left: key(.back, "Back") { KeyCap(systemImage: "arrow.uturn.backward") },
                     right: key(.home, "Home") { KeyCap(systemImage: "house.fill") })
            gap
            rockerRow
            gap
            mediaRow
            gap
            appRows
        }
        .padding(.horizontal, 26)
    }

    private var gap: some View { Spacer(minLength: 8) }

    // MARK: - Rows

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(vm.tvName).font(.headline).lineLimit(1)
                Text(statusText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Menu {
                Button { sheet = .apps } label: { Label("All apps", systemImage: "square.grid.2x2") }
                Button { sheet = .voice } label: { Label("Type on TV", systemImage: "keyboard") }
                Button { sheet = .settings } label: { Label("More keys & settings", systemImage: "ellipsis.circle") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("More")
            RemoteButton("Power", action: { vm.togglePower() }) {
                KeyCap(systemImage: "power", tint: Theme.power)
            }
        }
    }

    private var tvKey: some View {
        key(.tv, "TV") { TextKey(text: "TV") }
    }

    private var rockerRow: some View {
        HStack(alignment: .center) {
            RockerView(title: "Volume",
                       onUp: { vm.press(.volumeUp) },
                       onDown: { vm.press(.volumeDown) }) {
                VolumeWedge().stroke(.white.opacity(0.85), lineWidth: 1.6).frame(width: 18, height: 11)
            }
            Spacer()
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    RemoteButton("Voice search", action: { sheet = .voice }) {
                        KeyCap(systemImage: "waveform", size: 52)
                    }
                }
                key(.mute, "Mute") { KeyCap(systemImage: "speaker.slash") }
            }
            Spacer()
            RockerView(title: "Channel",
                       onUp: { vm.press(.channelUp) },
                       onDown: { vm.press(.channelDown) }) {
                Text("CH").font(.system(size: 13, weight: .bold))
            }
        }
    }

    private var mediaRow: some View {
        HStack {
            key(.play, "Play") { KeyCap(systemImage: "play.fill") }
                .frame(width: 60)
            Spacer()
            key(.pause, "Pause") { KeyCap(systemImage: "pause.fill") }
            Spacer()
            key(.guide, "Guide") { GlyphKey(shape: GuideGlyph()) }
                .frame(width: 60)
        }
    }

    private var appRows: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                appKey(.youtube)
                appKey(.netflix)
            }
            HStack(spacing: 10) {
                appKey(.disney)
                appKey(.prime)
            }
        }
    }

    // MARK: - Helpers

    private func sideKeys<L: View, R: View>(left: L, right: R) -> some View {
        HStack {
            left
            Spacer()
            right
        }
    }

    private func key<Face: View>(_ remoteKey: RemoteKey,
                                 _ label: String,
                                 repeats: Bool = false,
                                 @ViewBuilder face: () -> Face) -> some View {
        RemoteButton(label, repeats: repeats, action: { vm.press(remoteKey) }, label: face)
    }

    private func appKey(_ shortcut: AppShortcut) -> some View {
        RemoteButton(shortcut.rawValue, action: { vm.open(shortcut) }) {
            AppKey(title: shortcut.rawValue)
        }
    }

    private var statusColor: Color {
        switch (vm.isReachable, vm.isOn) {
        case (.some(false), _): return .red
        case (.some(true), .some(true)): return .green
        case (.some(true), .some(false)): return .orange
        default: return .gray
        }
    }

    private var statusText: String {
        switch (vm.isReachable, vm.isOn) {
        case (.some(false), _): return "Not reachable · \(vm.host)"
        case (.some(true), .some(true)): return "On · \(vm.host)"
        case (.some(true), .some(false)): return "Standby · \(vm.host)"
        default: return "Connecting… · \(vm.host)"
        }
    }
}
