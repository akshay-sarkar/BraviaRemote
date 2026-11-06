import ActivityKit
import SwiftUI

/// The Lock Screen / Dynamic Island remote.
struct RemoteActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isOn: Bool
    }

    var tvName: String
    /// `AppTheme` raw value, so the Lock Screen remote matches the app's theme.
    var theme: String
}

/// Accent colors per theme, shared by the widgets and the Lock Screen remote
/// (the extension can't see the app's full theme definitions).
enum WidgetPalette {
    static func accent(for theme: String?) -> Color {
        switch theme {
        case "aurora": return Color(red: 0.24, green: 0.88, blue: 0.54)
        case "crimson": return Color(red: 1.0, green: 0.29, blue: 0.29)
        case "banana": return Color(red: 0.97, green: 0.82, blue: 0.24)
        default: return Color(red: 0.96, green: 0.77, blue: 0.09) // midnight
        }
    }

    static func background(for theme: String?) -> LinearGradient {
        let colors: [Color]
        switch theme {
        case "aurora": colors = [Color(red: 0.04, green: 0.11, blue: 0.11), Color(red: 0.02, green: 0.04, blue: 0.05)]
        case "crimson": colors = [Color(red: 0.16, green: 0.06, blue: 0.20), Color(red: 0.03, green: 0.04, blue: 0.11)]
        case "banana": colors = [Color(red: 0.14, green: 0.15, blue: 0.19), Color(red: 0.05, green: 0.05, blue: 0.06)]
        default: colors = [Color(red: 0.10, green: 0.09, blue: 0.07), Color(red: 0.03, green: 0.03, blue: 0.04)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    static var currentTheme: String? { AppGroup.defaults.string(forKey: AppGroup.Key.theme) }
}
