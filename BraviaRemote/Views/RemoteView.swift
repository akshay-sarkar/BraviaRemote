import SwiftUI

/// Size presets so the remote fills each iPhone instead of just being scaled.
struct RemoteMetrics {
    let key: CGFloat
    let mediaKey: CGFloat
    let rockerWidth: CGFloat
    let dpad: CGFloat
    let rowSpacing: CGFloat
    let gridSpacing: CGFloat
    let padding: CGFloat
    let glyph: CGFloat

    static let headerHeight: CGFloat = 50

    /// Height of everything below the header (excluding the flexible poster gap).
    var controlsHeight: CGFloat { key * 2 + mediaKey + dpad + 12 + rowSpacing * 3 }

    /// - Parameters:
    ///   - size: space available to the remote, inside the safe area.
    ///   - textScale: Dynamic Type multiplier (1 at the default size), capped by the caller.
    static func make(for size: CGSize, textScale: CGFloat) -> RemoteMetrics {
        var m: RemoteMetrics
        switch size.width {
        case ..<385:  // iPhone SE, 12/13 mini
            m = RemoteMetrics(key: 56, mediaKey: 52, rockerWidth: 54, dpad: 0,
                              rowSpacing: 12, gridSpacing: 8, padding: 14, glyph: 18)
        case ..<420:  // iPhone 12–16, 15/16 Pro
            m = RemoteMetrics(key: 64, mediaKey: 58, rockerWidth: 58, dpad: 0,
                              rowSpacing: 16, gridSpacing: 10, padding: 16, glyph: 20)
        default:      // Plus / Pro Max
            m = RemoteMetrics(key: 70, mediaKey: 62, rockerWidth: 62, dpad: 0,
                              rowSpacing: 18, gridSpacing: 12, padding: 20, glyph: 22)
        }

        // Larger text → slightly taller keys and bigger glyphs.
        let grow = min(max(textScale, 1), 1.25)
        m = RemoteMetrics(key: (m.key * grow).rounded(), mediaKey: (m.mediaKey * grow).rounded(),
                          rockerWidth: m.rockerWidth, dpad: 0, rowSpacing: m.rowSpacing,
                          gridSpacing: m.gridSpacing, padding: m.padding, glyph: m.glyph * grow)

        // D-pad: as wide as the row allows, capped, then shrunk if the screen is short.
        let byWidth = size.width - m.padding * 2 - m.rockerWidth * 2 - 16
        let fixed = headerHeight + 12 + m.key * 2 + m.mediaKey + 12 + m.rowSpacing * 3
        let byHeight = size.height - fixed - 8
        let dpad = max(170, min(byWidth, byHeight, 310))
        return RemoteMetrics(key: m.key, mediaKey: m.mediaKey, rockerWidth: m.rockerWidth, dpad: dpad,
                             rowSpacing: m.rowSpacing, gridSpacing: m.gridSpacing, padding: m.padding, glyph: m.glyph)
    }
}

/// Main screen. All four themes share one layout: controls sit low, within thumb reach, and the poster shows at the top.
///
///   [TV switcher ▾]               [⋯] [⏻]
///   (poster)
///   TV      Input     Settings     123
///   VOL±   ( D-pad + OK )          CH±
///   Back    Voice     Mute        Home
///   Play         Pause           Guide
struct RemoteView: View {
    @EnvironmentObject private var vm: RemoteViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.legibilityWeight) private var legibilityWeight
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.default.rawValue
    @AppStorage(HardwareVolumeController.settingKey) private var hardwareVolume = true
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @StateObject private var volumeButtons = HardwareVolumeController()
    @State private var sheet: Sheet?

    enum Sheet: String, Identifiable {
        case apps, voice, numbers, settings, inputs
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = RemoteMetrics.make(for: geo.size, textScale: textScale)
            // Last resort for unusually short windows: scale the whole remote.
            let needed = RemoteMetrics.headerHeight + 12 + metrics.controlsHeight + 14
            let scale = min(1, geo.size.height / needed)
            content(metrics)
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(PosterBackground())
        .background(HiddenVolumeView(controller: volumeButtons).frame(width: 1, height: 1))
        .overlay(alignment: .top) {
            if let toast = vm.toast {
                ToastView(text: toast).padding(.top, 4)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.easeInOut(duration: 0.2), value: vm.toast)
        .animation(.easeInOut(duration: 0.35), value: themeRaw)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .apps: AppsView()
            case .voice: KeyboardSheet()
            case .numbers: NumberPadSheet()
            case .settings: SettingsView()
            case .inputs: InputPickerSheet()
            }
        }
        .sheet(isPresented: $vm.showingSetup, onDismiss: { vm.cancelPairing() }) {
            SetupView(isSheet: true)
        }
        .onAppear {
            vm.refresh()
            volumeButtons.onUp = { vm.press(.volumeUp) }
            volumeButtons.onDown = { vm.press(.volumeDown) }
            updateVolumeButtons()
        }
        .onDisappear { volumeButtons.stop() }
        .onChange(of: scenePhase) { _, _ in updateVolumeButtons() }
        .onChange(of: hardwareVolume) { _, _ in updateVolumeButtons() }
        .onChange(of: sheet) { _, _ in updateVolumeButtons() }
        .onChange(of: vm.showingSetup) { _, _ in updateVolumeButtons() }
    }

    /// Volume buttons drive the TV only while the remote itself is on screen and active,
    /// not while typing in a sheet or after the app goes to the background.
    private func updateVolumeButtons() {
        let wanted = hardwareVolume && scenePhase == .active && sheet == nil && !vm.showingSetup
        if wanted { volumeButtons.start() } else { volumeButtons.stop() }
    }

    private func content(_ m: RemoteMetrics) -> some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            VStack(spacing: m.rowSpacing) {
                HStack(spacing: m.gridSpacing) {
                    key(.tv, "TV", m) { label("TV", m) }
                    RemoteButton("Inputs", action: { sheet = .inputs }) {
                        ThemedKey(height: m.key) { glyph(InputGlyph(), m) }
                    }
                    key(.actionMenu, "Settings", m, accent: true) { symbol("gearshape.fill", m) }
                    RemoteButton("Number pad", action: { sheet = .numbers }) {
                        ThemedKey(height: m.key) { label("123", m) }
                    }
                }

                HStack(spacing: 0) {
                    ThemedRocker(title: "Volume", isChannel: false, width: m.rockerWidth, height: m.dpad + 12,
                                 onUp: { vm.press(.volumeUp) }, onDown: { vm.press(.volumeDown) }) {
                        VolumeWedge().stroke(lineWidth: 1.6).frame(width: 18, height: 11)
                    }
                    Spacer(minLength: 8)
                    ThemedDPad(size: m.dpad) { vm.press($0) }
                    Spacer(minLength: 8)
                    ThemedRocker(title: "Channel", isChannel: true, width: m.rockerWidth, height: m.dpad + 12,
                                 onUp: { vm.press(.channelUp) }, onDown: { vm.press(.channelDown) }) {
                        Text("CH").font(.system(size: 12, weight: .heavy)).tracking(1)
                    }
                }

                HStack(spacing: m.gridSpacing) {
                    key(.back, "Back", m) { symbol("arrow.uturn.backward", m) }
                    RemoteButton("Voice search", action: { sheet = .voice }) {
                        ThemedKey(height: m.key, accent: true) { symbol("mic.fill", m) }
                    }
                    key(.mute, "Mute", m) { symbol("speaker.slash.fill", m) }
                    key(.home, "Home", m) { symbol("house.fill", m) }
                }

                HStack(spacing: m.gridSpacing) {
                    key(.play, "Play", m, accent: true, media: true) { symbol("play.fill", m, scale: 0.85) }
                    key(.pause, "Pause", m, accent: true, media: true) { symbol("pause.fill", m, scale: 0.85) }
                    key(.guide, "Guide", m, media: true) { glyph(GuideGlyph(), m, scale: 1.15) }
                }
            }
        }
        .padding(.horizontal, m.padding)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            tvSwitcher
            Spacer(minLength: 8)
            Menu {
                Picker("Theme", systemImage: "paintpalette", selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.name, systemImage: theme.symbol).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.menu)
                Divider()
                Button { sheet = .inputs } label: { Label("Inputs", systemImage: "rectangle.on.rectangle") }
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
        .frame(height: RemoteMetrics.headerHeight)
    }

    /// TV name + status. Tap to switch between saved TVs or add one.
    private var tvSwitcher: some View {
        Menu {
            ForEach(vm.tvs) { tv in
                Button {
                    vm.switchTo(tv.id)
                } label: {
                    if tv.id == vm.currentID {
                        Label(tv.name, systemImage: "checkmark")
                    } else {
                        Text(tv.name)
                    }
                }
            }
            Divider()
            Button { vm.beginAddingTV() } label: { Label("Add a TV", systemImage: "plus") }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(vm.tvName).font(.headline).lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .opacity(0.7)
                    }
                    Text(statusText).font(.caption).opacity(0.75).lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 6)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(vm.tvName), \(statusText). Switch TV")
    }

    // MARK: - Helpers

    private func key<Face: View>(_ remoteKey: RemoteKey,
                                 _ accessibility: String,
                                 _ m: RemoteMetrics,
                                 accent: Bool = false,
                                 media: Bool = false,
                                 @ViewBuilder face: () -> Face) -> some View {
        RemoteButton(accessibility, action: { vm.press(remoteKey) }) {
            ThemedKey(height: media ? m.mediaKey : m.key, accent: accent, compact: !media, content: face)
        }
    }

    /// Bold Text bumps every key glyph one weight heavier.
    private func weight(_ base: Font.Weight) -> Font.Weight {
        guard legibilityWeight == .bold else { return base }
        switch base {
        case .semibold: return .bold
        case .bold: return .heavy
        default: return .black
        }
    }

    private func symbol(_ name: String, _ m: RemoteMetrics, scale: CGFloat = 1) -> some View {
        Image(systemName: name).font(.system(size: m.glyph * scale, weight: weight(.semibold)))
    }

    private func label(_ text: String, _ m: RemoteMetrics) -> some View {
        Text(text)
            .font(.system(size: m.glyph * 0.85, weight: weight(.bold), design: .rounded))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }

    private func glyph<S: Shape>(_ shape: S, _ m: RemoteMetrics, scale: CGFloat = 1.1) -> some View {
        shape
            .stroke(style: StrokeStyle(lineWidth: legibilityWeight == .bold ? 2.6 : 2, lineCap: .round, lineJoin: .round))
            .frame(width: m.glyph * scale, height: m.glyph * scale)
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
