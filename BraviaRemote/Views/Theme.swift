import SwiftUI

// MARK: - Theme tokens

/// The four remote skins. The choice is stored with `@AppStorage(AppTheme.storageKey)`.
enum AppTheme: String, CaseIterable, Identifiable {
    case aurora, midnight, crimson, banana

    static let storageKey = "app.theme"
    static let `default`: AppTheme = .midnight

    enum KeyStyle { case rounded, chamfer, round }
    enum DPadStyle { case glow, signal, rings, goggle }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aurora: return "Aurora Graphite"
        case .midnight: return "Midnight Signal"
        case .crimson: return "Crimson Night"
        case .banana: return "Banana Lab"
        }
    }

    var symbol: String {
        switch self {
        case .aurora: return "sparkles"
        case .midnight: return "moon.stars.fill"
        case .crimson: return "building.2.fill"
        case .banana: return "flask.fill"
        }
    }

    /// Asset-catalog name of the full-screen poster.
    var poster: String {
        switch self {
        case .aurora: return "PosterAurora"
        case .midnight: return "PosterMidnight"
        case .crimson: return "PosterCrimson"
        case .banana: return "PosterBanana"
        }
    }

    var accent: Color {
        switch self {
        case .aurora: return Color(hex: 0x3EE08A)
        case .midnight: return Color(hex: 0xF5C518)
        case .crimson: return Color(hex: 0xFF4B4B)
        case .banana: return Color(hex: 0xF7D23E)
        }
    }

    /// Default glyph colour on keys.
    var ink: Color {
        switch self {
        case .aurora: return Color(hex: 0xF2F4F7)
        case .midnight: return Color(hex: 0xECECEC)
        case .crimson: return .white
        case .banana: return Color(hex: 0xF7D23E)
        }
    }

    /// Tint laid over the frosted material on every key.
    var glass: Color {
        switch self {
        case .aurora: return Color(hex: 0x161A1E, opacity: 0.50)
        case .midnight: return Color(hex: 0x141416, opacity: 0.60)
        case .crimson: return Color(hex: 0x0E142C, opacity: 0.55)
        case .banana: return Color(hex: 0x181A20, opacity: 0.60)
        }
    }

    var edge: Color {
        switch self {
        case .aurora: return .white.opacity(0.12)
        case .midnight: return Color(hex: 0xF5C518, opacity: 0.20)
        case .crimson: return .white.opacity(0.14)
        case .banana: return .white.opacity(0.10)
        }
    }

    var keyStyle: KeyStyle {
        switch self {
        case .aurora, .banana: return .rounded
        case .midnight: return .chamfer
        case .crimson: return .round
        }
    }

    var dpad: DPadStyle {
        switch self {
        case .aurora: return .glow
        case .midnight: return .signal
        case .crimson: return .rings
        case .banana: return .goggle
        }
    }

    // Rockers
    var rockerUsesMaterial: Bool { self == .aurora || self == .midnight }

    var volumeFill: AnyShapeStyle {
        switch self {
        case .aurora, .midnight: return AnyShapeStyle(glass)
        case .crimson:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x6A1824, opacity: 0.85), Color(hex: 0x3A0D16, opacity: 0.85)],
                                                startPoint: .top, endPoint: .bottom))
        case .banana:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x4A86CF), Color(hex: 0x2B5690)],
                                                startPoint: .top, endPoint: .bottom))
        }
    }

    var channelFill: AnyShapeStyle {
        switch self {
        case .crimson:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x1F3F8C, opacity: 0.85), Color(hex: 0x132656, opacity: 0.85)],
                                                startPoint: .top, endPoint: .bottom))
        default: return volumeFill
        }
    }

    var rockerLabel: Color {
        switch self {
        case .aurora: return Color(hex: 0x9FE9C2)
        case .midnight: return Color(hex: 0xF5C518)
        case .crimson: return Color(hex: 0xFFD5D5)
        case .banana: return Color(hex: 0xE3EEFC)
        }
    }

    // Power key
    var powerFill: AnyShapeStyle {
        switch self {
        case .aurora: return AnyShapeStyle(Color(hex: 0x3EE08A, opacity: 0.18))
        case .midnight: return AnyShapeStyle(Color(hex: 0xF5C518))
        case .crimson: return AnyShapeStyle(Color(hex: 0xE23636))
        case .banana: return AnyShapeStyle(Color(hex: 0x181A20, opacity: 0.75))
        }
    }

    var powerInk: Color {
        switch self {
        case .aurora: return accent
        case .midnight: return Color(hex: 0x111111)
        case .crimson: return .white
        case .banana: return accent
        }
    }

    var powerStroke: Color? {
        switch self {
        case .aurora: return Color(hex: 0x3EE08A, opacity: 0.5)
        case .banana: return accent
        default: return nil
        }
    }

    var powerGlow: Color {
        switch self {
        case .midnight: return Color(hex: 0xF5C518, opacity: 0.45)
        case .crimson: return Color(hex: 0xE23636, opacity: 0.55)
        default: return .clear
        }
    }

    // D-pad
    var arrow: Color {
        switch self {
        case .aurora: return Color(hex: 0xCFEEE0)
        case .midnight, .banana: return accent
        case .crimson: return .white
        }
    }

    var okFill: AnyShapeStyle {
        switch self {
        case .aurora: return AnyShapeStyle(Color(hex: 0x0E1214, opacity: 0.92))
        case .midnight: return AnyShapeStyle(Color(hex: 0x0F1012))
        case .crimson:
            return AnyShapeStyle(RadialGradient(colors: [Color(hex: 0xFF6B6B), Color(hex: 0xB81F2A)],
                                                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 70))
        case .banana:
            return AnyShapeStyle(RadialGradient(colors: [Color(hex: 0xFDE88A), Color(hex: 0xE7B81C)],
                                                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 70))
        }
    }

    var okInk: Color {
        switch self {
        case .aurora, .midnight: return accent
        case .crimson: return .white
        case .banana: return Color(hex: 0x2A2100)
        }
    }

    var okStroke: Color? {
        switch self {
        case .aurora, .midnight: return accent
        default: return nil
        }
    }

    var okGlow: Color {
        switch self {
        case .aurora: return Color(hex: 0x3EE08A, opacity: 0.35)
        case .midnight: return Color(hex: 0xF5C518, opacity: 0.40)
        case .crimson: return Color(hex: 0xE23636, opacity: 0.55)
        case .banana: return Color(hex: 0xF7D23E, opacity: 0.40)
        }
    }

    // Shapes
    func keyShape(radius: CGFloat = 18) -> AnyShape {
        switch keyStyle {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .chamfer: return AnyShape(ChamferedRectangle(cut: 12))
        case .round: return AnyShape(Capsule())
        }
    }

    var rockerShape: AnyShape {
        switch keyStyle {
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
        case .chamfer: return AnyShape(ChamferedRectangle(cut: 14))
        case .round: return AnyShape(Capsule())
        }
    }
}

// MARK: - Environment

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Rectangle with 45° cut corners (Midnight Signal keys).
struct ChamferedRectangle: Shape {
    var cut: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let c = min(cut, rect.width / 2, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}

// MARK: - Themed building blocks

/// Full-screen poster with a bottom-heavy shade so the keys stay readable.
struct PosterBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            Image(theme.poster)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .overlay(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.15), location: 0.3),
                .init(color: .black.opacity(0.5), location: 0.6),
                .init(color: .black.opacity(0.82), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea()
        .id(theme) // cross-fade when the theme changes
        .transition(.opacity)
    }
}

/// Frosted key face in the current theme's shape.
struct ThemedKey<Content: View>: View {
    @Environment(\.appTheme) private var theme
    private let height: CGFloat
    private let accent: Bool
    private let compact: Bool
    private let content: Content

    /// `compact` keys become circles in themes with round keys (Crimson Night).
    init(height: CGFloat = 64, accent: Bool = false, compact: Bool = true, @ViewBuilder content: () -> Content) {
        self.height = height
        self.accent = accent
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        let shape = theme.keyShape()
        let circular = compact && theme.keyStyle == .round
        content
            .foregroundStyle(accent ? theme.accent : theme.ink)
            .frame(width: circular ? height : nil, height: height)
            .frame(maxWidth: circular ? nil : .infinity)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(theme.glass)
                    shape.stroke(theme.edge, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity)
    }
}

/// Vertical + / − rocker for the sides of the D-pad.
struct ThemedRocker<Mark: View>: View {
    @Environment(\.appTheme) private var theme
    private let title: String
    private let isChannel: Bool
    private let height: CGFloat
    private let onUp: () -> Void
    private let onDown: () -> Void
    private let mark: Mark

    init(title: String,
         isChannel: Bool,
         height: CGFloat,
         onUp: @escaping () -> Void,
         onDown: @escaping () -> Void,
         @ViewBuilder mark: () -> Mark) {
        self.title = title
        self.isChannel = isChannel
        self.height = height
        self.onUp = onUp
        self.onDown = onDown
        self.mark = mark()
    }

    var body: some View {
        let shape = theme.rockerShape
        VStack(spacing: 0) {
            RemoteButton("\(title) up", repeats: true, action: onUp) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: height * 0.42)
            }
            Spacer(minLength: 0)
            mark.foregroundStyle(theme.rockerLabel)
            Spacer(minLength: 0)
            RemoteButton("\(title) down", repeats: true, action: onDown) {
                Image(systemName: "minus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: height * 0.42)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 58, height: height)
        .background {
            ZStack {
                if theme.rockerUsesMaterial { shape.fill(.ultraThinMaterial) }
                shape.fill(isChannel ? theme.channelFill : theme.volumeFill)
                shape.stroke(theme.edge, lineWidth: 1)
            }
        }
    }
}

/// The D-pad plate, arrows and OK key, styled per theme.
struct ThemedDPad: View {
    @Environment(\.appTheme) private var theme
    let size: CGFloat
    let onKey: (RemoteKey) -> Void

    var body: some View {
        let offset = size * 0.39
        ZStack {
            plate
            arrow(.up, "arrowtriangle.up.fill", "Up").offset(y: -offset)
            arrow(.down, "arrowtriangle.down.fill", "Down").offset(y: offset)
            arrow(.left, "arrowtriangle.left.fill", "Left").offset(x: -offset)
            arrow(.right, "arrowtriangle.right.fill", "Right").offset(x: offset)
            RemoteButton("OK", action: { onKey(.confirm) }) { okFace }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var plate: some View {
        switch theme.dpad {
        case .glow:
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(RadialGradient(colors: [Color(hex: 0x1A2024, opacity: 0.7), Color(hex: 0x0E1214, opacity: 0.85)],
                                             center: .center, startRadius: size * 0.25, endRadius: size / 2))
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: theme.accent.opacity(0.18), radius: 20)
        case .signal:
            ZStack {
                Circle().fill(Color.black.opacity(0.6))
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x18181B, opacity: 0.92), Color(hex: 0x0C0C0E, opacity: 0.95)],
                                         center: .center, startRadius: size * 0.2, endRadius: size / 2))
                    .overlay(Circle().strokeBorder(Color(hex: 0x2D2E33), lineWidth: 2))
                    .padding(6)
            }
            .shadow(color: theme.accent.opacity(0.25), radius: 18)
        case .rings:
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0x141C3A, opacity: 0.9), Color(hex: 0x0A0E20, opacity: 0.92)],
                                             center: .center, startRadius: 0, endRadius: size / 2))
                Circle().strokeBorder(Color(hex: 0xE23636, opacity: 0.8), lineWidth: 1.5)
                Circle().inset(by: size * 0.1).stroke(Color(hex: 0x2F63D6, opacity: 0.7), lineWidth: 1)
                Circle().inset(by: size * 0.21).stroke(Color(hex: 0xE23636, opacity: 0.45), lineWidth: 1)
            }
            .shadow(color: Color(hex: 0xE23636, opacity: 0.25), radius: 18)
        case .goggle:
            ZStack {
                Circle().fill(AngularGradient(colors: [Color(hex: 0x8D939E), Color(hex: 0xEEF0F4), Color(hex: 0x7D838E),
                                                       Color(hex: 0xDDE1E7), Color(hex: 0x8D939E)],
                                              center: .center, startAngle: .degrees(200), endAngle: .degrees(560)))
                Circle().inset(by: 16)
                    .fill(RadialGradient(colors: [Color(hex: 0x2A2C33), Color(hex: 0x141519)],
                                         center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.45))
                Circle().inset(by: 16).strokeBorder(Color(hex: 0x3A3C43), lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
        }
    }

    private var okFace: some View {
        let d = size * 0.4
        return Circle()
            .fill(theme.okFill)
            .overlay {
                if let stroke = theme.okStroke {
                    Circle().strokeBorder(stroke, lineWidth: 2)
                }
            }
            .overlay(
                Text("OK")
                    .font(.system(size: d * 0.2, weight: .heavy))
                    .foregroundStyle(theme.okInk)
            )
            .frame(width: d, height: d)
            .shadow(color: theme.okGlow, radius: 14)
    }

    private func arrow(_ key: RemoteKey, _ icon: String, _ label: String) -> some View {
        RemoteButton(label, repeats: true, action: { onKey(key) }) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(theme.arrow)
                .frame(width: size * 0.28, height: size * 0.28)
        }
    }
}

/// Power key, top-right of the header.
struct PowerKey: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        let shape = theme.keyShape(radius: 15)
        Image(systemName: "power")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(theme.powerInk)
            .frame(width: 46, height: 46)
            .background { shape.fill(theme.powerFill) }
            .overlay {
                if let stroke = theme.powerStroke {
                    shape.stroke(stroke, lineWidth: 1.5)
                }
            }
            .shadow(color: theme.powerGlow, radius: 10)
    }
}

/// Theme picker tiles (Settings).
struct ThemeGrid: View {
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.default.rawValue

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                let selected = theme.rawValue == themeRaw
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { themeRaw = theme.rawValue }
                } label: {
                    VStack(spacing: 6) {
                        Color.clear
                            .frame(height: 120)
                            .overlay(Image(theme.poster).resizable().scaledToFill())
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected ? theme.accent : Color.white.opacity(0.1), lineWidth: selected ? 3 : 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(theme.accent)
                                        .padding(6)
                                }
                            }
                        Text(theme.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? theme.accent : .primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.name) theme\(selected ? ", selected" : "")")
            }
        }
        .padding(.vertical, 4)
    }
}
