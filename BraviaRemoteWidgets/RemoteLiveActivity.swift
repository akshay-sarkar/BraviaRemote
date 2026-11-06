import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen + Dynamic Island remote, started from the app (⋯ → Lock Screen remote).
struct RemoteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemoteActivityAttributes.self) { context in
            LockScreenRemote(context: context)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent = WidgetPalette.accent(for: context.attributes.theme)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.tvName, systemImage: "tv.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: TVPowerIntent(action: .toggle)) {
                        Image(systemName: "power")
                            .font(.body.weight(.bold))
                            .foregroundStyle(context.state.isOn ? accent : .white)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RemoteActivityButtons(accent: accent)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "tv.fill").foregroundStyle(accent)
            } compactTrailing: {
                Image(systemName: context.state.isOn ? "speaker.wave.2.fill" : "power")
                    .foregroundStyle(accent)
            } minimal: {
                Image(systemName: "tv.fill").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenRemote: View {
    let context: ActivityViewContext<RemoteActivityAttributes>

    var body: some View {
        let accent = WidgetPalette.accent(for: context.attributes.theme)
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "tv.fill").foregroundStyle(accent)
                Text(context.attributes.tvName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(context.state.isOn ? "On" : "Off")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(context.state.isOn ? accent.opacity(0.25) : .white.opacity(0.12)))
                Spacer()
                Button(intent: TVPowerIntent(action: .toggle)) {
                    Image(systemName: "power")
                        .font(.body.weight(.bold))
                        .foregroundStyle(context.state.isOn ? accent : .white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            RemoteActivityButtons(accent: accent)
        }
        .foregroundStyle(.white)
        .padding(14)
    }
}

/// Volume, mute and play/pause, shared by the Lock Screen and the expanded Dynamic Island.
private struct RemoteActivityButtons: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            key(TVVolumeDownIntent(steps: 1), "minus")
            key(MuteTVIntent(), "speaker.slash.fill")
            key(TVVolumeUpIntent(steps: 1), "plus")
            key(PressTVButtonIntent(button: .play), "play.fill", tint: accent)
            key(PressTVButtonIntent(button: .pause), "pause.fill", tint: accent)
        }
    }

    private func key<I: AppIntent>(_ intent: I, _ symbol: String, tint: Color = .white) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
