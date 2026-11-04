import SwiftUI

@main
struct BraviaRemoteApp: App {
    @StateObject private var vm = RemoteViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
            .preferredColorScheme(.dark)
            .animation(.default, value: vm.isPaired)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { vm.refresh() }
            }
        }
    }
}
