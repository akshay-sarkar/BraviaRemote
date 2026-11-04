import SwiftUI

@main
struct BraviaRemoteApp: App {
    @StateObject private var vm = RemoteViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.default.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .default }

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
        }
    }
}
