import SwiftUI

/// Main screen. All four themes share one layout. Controls sit low in thumb reach,
/// and the poster shows through at the top.
///
///   [name/status]                 [⋯] [⏻]
///   (poster)
///   TV      Input     Settings     123
///   VOL±   ( D-pad + OK )          CH±
///   Back    Voice     Mute        Home
///   Play         Pause           Guide
struct RemoteView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.appTheme) private var theme
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.default.rawValue
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case apps, voice, numbers, settings
        var id: String { rawValue }
    }

    /// Smallest height the layout needs; shorter screens scale the whole remote down.
    private let minimumHeight: CGFloat = 590

    var body: some View {
        GeometryReader { geo in
            let scale = min(1, geo.size.height / minimumHeight)
            let width = geo.size.width / scale
            content(width: width)
                .frame(width: width, height: geo.size.height / scale)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(PosterBackground())
        .overlay(alignment: .top) {
            if let toast = vm.toast {
                ToastView(text: toast).padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.toast)
        .animation(.easeInOut(duration: 0.35), value: themeRaw)
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

    private func content(width: CGFloat) -> some View {
        let rockerWidth: CGFloat = 58
        let dpadSize = min(width - 32 - rockerWidth * 2 - 16, 290)

        return VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    key(.tv, "TV") { Text("TV").font(.system(size: 17, weight: .bold, design: .rounded)) }
                    key(.input, "Input") { glyph(InputGlyph()) }
                    key(.actionMenu, "Settings", accent: true) {
                        Image(systemName: "gearshape.fill").font(.system(size: 20, weight: .semibold))
                    }
                    RemoteButton("Number pad", action: { sheet = .numbers }) {
                        ThemedKey { Text("123").font(.system(size: 17, weight: .bold, design: .rounded)) }
                    }
                }

                HStack(spacing: 0) {
                    ThemedRocker(title: "Volume", isChannel: false, height: dpadSize + 12,
                                 onUp: { vm.press(.volumeUp) }, onDown: { vm.press(.volumeDown) }) {
                        VolumeWedge().stroke(lineWidth: 1.6).frame(width: 18, height: 11)
                    }
                    Spacer(minLength: 8)
                    ThemedDPad(size: dpadSize) { vm.press($0) }
                    Spacer(minLength: 8)
                    ThemedRocker(title: "Channel", isChannel: true, height: dpadSize + 12,
                                 onUp: { vm.press(.channelUp) }, onDown: { vm.press(.channelDown) }) {
                        Text("CH").font(.system(size: 12, weight: .heavy)).tracking(1)
                    }
                }

                HStack(spacing: 10) {
                    key(.back, "Back") { symbol("arrow.uturn.backward") }
                    RemoteButton("Voice search", action: { sheet = .voice }) {
                        ThemedKey(accent: true) { symbol("mic.fill") }
                    }
                    key(.mute, "Mute") { symbol("speaker.slash.fill") }
                    key(.home, "Home") { symbol("house.fill") }
                }

                HStack(spacing: 10) {
                    key(.play, "Play", accent: true, height: 58, compact: false) { symbol("play.fill", size: 17) }
                    key(.pause, "Pause", accent: true, height: 58, compact: false) { symbol("pause.fill", size: 17) }
                    key(.guide, "Guide", height: 58, compact: false) { glyph(GuideGlyph(), size: 23) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.tvName).font(.headline).lineLimit(1)
                Text(statusText).font(.caption).opacity(0.75).lineLimit(1)
            }
            .shadow(color: .black.opacity(0.6), radius: 6)
            Spacer()
            Menu {
                Picker("Theme", systemImage: "paintpalette", selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.name, systemImage: theme.symbol).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.menu)
                Divider()
                Button { sheet = .apps } label: { Label("All apps", systemImage: "square.grid.2x2") }
                Button { sheet = .voice } label: { Label("Type on TV", systemImage: "keyboard") }
                Button { sheet = .settings } label: { Label("More keys & settings", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("More")
            RemoteButton("Power", action: { vm.togglePower() }) { PowerKey() }
        }
        .frame(height: 50)
    }

    // MARK: - Helpers

    private func key<Face: View>(_ remoteKey: RemoteKey,
                                 _ label: String,
                                 accent: Bool = false,
                                 height: CGFloat = 64,
                                 compact: Bool = true,
                                 @ViewBuilder face: () -> Face) -> some View {
        RemoteButton(label, action: { vm.press(remoteKey) }) {
            ThemedKey(height: height, accent: accent, compact: compact, content: face)
        }
    }

    private func symbol(_ name: String, size: CGFloat = 20) -> some View {
        Image(systemName: name).font(.system(size: size, weight: .semibold))
    }

    private func glyph<S: Shape>(_ shape: S, size: CGFloat = 22) -> some View {
        shape
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }

    private var statusColor: Color {
        switch (vm.isReachable, vm.isOn) {
        case (.some(false), _): return .red
        case (.some(true), .some(true)): return theme.accent
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
