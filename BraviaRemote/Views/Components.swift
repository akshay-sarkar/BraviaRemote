import SwiftUI

enum Theme {
    static let background = LinearGradient(colors: [Color(white: 0.11), Color(white: 0.04)],
                                           startPoint: .top, endPoint: .bottom)
    static let key = Color.white.opacity(0.09)
    static let keyStroke = Color.white.opacity(0.08)
    /// The green power glyph printed on the BRAVIA remote.
    static let power = Color(red: 0.24, green: 0.80, blue: 0.62)
}

/// Fires on touch-down like a physical remote; optionally repeats while held.
struct RemoteButton<Label: View>: View {
    private let repeats: Bool
    private let accessibilityText: String
    private let action: () -> Void
    private let label: Label

    @State private var pressed = false
    @State private var repeatTask: Task<Void, Never>?

    init(_ accessibilityText: String,
         repeats: Bool = false,
         action: @escaping () -> Void,
         @ViewBuilder label: () -> Label) {
        self.accessibilityText = accessibilityText
        self.repeats = repeats
        self.action = action
        self.label = label()
    }

    var body: some View {
        label
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.9 : 1)
            .opacity(pressed ? 0.65 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        action()
                        if repeats { startRepeating() }
                    }
                    .onEnded { _ in
                        pressed = false
                        repeatTask?.cancel()
                        repeatTask = nil
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    private func startRepeating() {
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
    }
}

/// Round key face that holds any glyph.
struct RoundKey<Content: View>: View {
    var size: CGFloat
    private let content: Content

    init(size: CGFloat = 50, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.key))
            .overlay(Circle().stroke(Theme.keyStroke, lineWidth: 1))
    }
}

/// Round key with an SF Symbol.
struct KeyCap: View {
    let systemImage: String
    var tint: Color = .white
    var size: CGFloat = 50

    var body: some View {
        RoundKey(size: size) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

/// Capsule app button (YouTube / Netflix / Disney+ / Prime Video row).
struct AppKey: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(Capsule().fill(Theme.key))
            .overlay(Capsule().stroke(Theme.keyStroke, lineWidth: 1))
    }
}

/// Small transient message at the top of the screen.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
