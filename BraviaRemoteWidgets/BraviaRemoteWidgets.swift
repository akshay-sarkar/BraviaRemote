import SwiftUI
import WidgetKit

@main
struct BraviaRemoteWidgets: WidgetBundle {
    var body: some Widget {
        RemoteWidget()
        PowerWidget()
        RemoteLiveActivity()
        if #available(iOS 18.0, *) {
            TVPowerControl()
            TVMuteControl()
        }
    }
}
