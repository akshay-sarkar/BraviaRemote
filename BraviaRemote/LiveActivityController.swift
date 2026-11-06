import ActivityKit
import Foundation

/// Starts, updates and ends the Lock Screen / Dynamic Island remote.
@MainActor
enum LiveActivityController {
    static let settingKey = "lockScreenRemote"

    static var isRunning: Bool { !Activity<RemoteActivityAttributes>.activities.isEmpty }

    static var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Shows the remote for `tvName`, replacing one for a different TV or theme.
    static func start(tvName: String, theme: String, isOn: Bool) {
        guard isAllowed else { return }
        let attributes = RemoteActivityAttributes(tvName: tvName, theme: theme)
        let content = ActivityContent(state: RemoteActivityAttributes.ContentState(isOn: isOn),
                                      staleDate: Date().addingTimeInterval(8 * 3600))
        let running = Activity<RemoteActivityAttributes>.activities
        if let current = running.first, current.attributes.tvName == tvName, current.attributes.theme == theme {
            Task { await current.update(content) }
            return
        }
        end()
        _ = try? Activity<RemoteActivityAttributes>.request(attributes: attributes, content: content, pushType: nil)
    }

    static func update(isOn: Bool) {
        let content = ActivityContent(state: RemoteActivityAttributes.ContentState(isOn: isOn),
                                      staleDate: Date().addingTimeInterval(8 * 3600))
        for activity in Activity<RemoteActivityAttributes>.activities {
            Task { await activity.update(content) }
        }
    }

    static func end() {
        for activity in Activity<RemoteActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
