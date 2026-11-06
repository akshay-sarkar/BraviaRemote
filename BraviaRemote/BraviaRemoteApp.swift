import SwiftUI
import WidgetKit

@main
struct BraviaRemoteApp: App {
    @StateObject private var vm = RemoteViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.default.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .default }

    /// Widgets and the Lock Screen remote follow the app's theme colors.
    private func shareThemeWithWidgets() {
        AppGroup.defaults.set(theme.rawValue, forKey: AppGroup.Key.theme)
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if vm.isPaired {
                    RemoteView()
                } else {
                    SetupView()
                }
            }
            .environmentObject(vm)
            .environment(\.appTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(.dark)
            .animation(.default, value: vm.isPaired)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { vm.refresh() }
            }
            .onAppear { shareThemeWithWidgets() }
            .onChange(of: themeRaw) { _, _ in
                shareThemeWithWidgets()
                vm.lockScreenRemoteSync()
            }
        }
    }
}
