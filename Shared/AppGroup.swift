import Foundation

/// Storage shared by the app and its widget extension.
///
/// Sideloading tools usually keep the app group. If one doesn't, everything still works:
/// each process just falls back to its own private storage, and widgets show a generic TV name.
enum AppGroup {
    static let id = "group.com.akshay.BraviaRemote"

    static let defaults: UserDefaults = UserDefaults(suiteName: id) ?? .standard

    /// Keys written by the app for the widgets.
    enum Key {
        static let theme = "widget.theme"
        static let lastPower = "widget.lastPower"
    }
}
