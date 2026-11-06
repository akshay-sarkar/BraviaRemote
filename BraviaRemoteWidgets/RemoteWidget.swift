import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct RemoteEntry: TimelineEntry {
    let date: Date
    let tvName: String
    let hasTV: Bool
    let theme: String?

    static let placeholder = RemoteEntry(date: .now, tvName: "BRAVIA 4K VH21", hasTV: true, theme: nil)
}

struct RemoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RemoteEntry) -> Void) {
        completion(context.isPreview ? .placeholder : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteEntry>) -> Void) {
        // Nothing changes on a schedule; the app reloads widgets when TVs or the theme change.
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> RemoteEntry {
        let tv = TVStore.currentTV()
        return RemoteEntry(date: .now,
                           tvName: tv?.name ?? "TV",
                           hasTV: tv != nil,
                           theme: WidgetPalette.currentTheme)
    }
}

// MARK: - Remote widget (Home Screen)

struct RemoteWidget: Widget {
    let kind = "com.akshay.BraviaRemote.widget.remote"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemoteProvider()) { entry in
            RemoteWidgetView(entry: entry)
        }
        .configurationDisplayName("TV Remote")
        .description("Power, mute and volume for your BRAVIA, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RemoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RemoteEntry

    private var accent: Color { WidgetPalette.accent(for: entry.theme) }

    var body: some View {
        Group {
            if !entry.hasTV {
                VStack(spacing: 6) {
                    Image(systemName: "tv").font(.title2)
                    Text("Open Bravia Remote to pair your TV").font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.8))
            } else if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .containerBackground(for: .widget) { WidgetPalette.background(for: entry.theme) }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "tv.fill").font(.caption2).foregroundStyle(accent)
            Text(entry.tvName).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    private var small: some View {
        VStack(spacing: 8) {
            header
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    key(TVPowerIntent(action: .toggle), "power", tint: accent)
                    key(MuteTVIntent(), "speaker.slash.fill")
                }
                GridRow {
                    key(TVVolumeDownIntent(steps: 1), "minus")
                    key(TVVolumeUpIntent(steps: 1), "plus")
                }
            }
        }
    }

    private var medium: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 8) {
                key(TVPowerIntent(action: .toggle), "power", tint: accent)
                key(PressTVButtonIntent(button: .home), "house.fill")
                key(PressTVButtonIntent(button: .back), "arrow.uturn.backward")
                key(MuteTVIntent(), "speaker.slash.fill")
            }
            HStack(spacing: 8) {
                key(TVVolumeDownIntent(steps: 1), "minus")
                key(TVVolumeUpIntent(steps: 1), "plus")
                key(PressTVButtonIntent(button: .play), "play.fill", tint: accent)
                key(PressTVButtonIntent(button: .pause), "pause.fill", tint: accent)
            }
        }
    }

    private func key<I: AppIntent>(_ intent: I, _ symbol: String, tint: Color = .white) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Power widget (Lock Screen + small Home Screen)

struct PowerWidget: Widget {
    let kind = "com.akshay.BraviaRemote.widget.power"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemoteProvider()) { entry in
            PowerWidgetView(entry: entry)
        }
        .configurationDisplayName("TV Power")
        .description("One tap to turn your BRAVIA on or off.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct PowerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RemoteEntry

    var body: some View {
        Group {
            if family == .accessoryInline {
                Label(entry.tvName, systemImage: "tv")
            } else {
                Button(intent: TVPowerIntent(action: .toggle)) {
                    ZStack {
                        AccessoryWidgetBackground()
                        Image(systemName: "power").font(.title2.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
