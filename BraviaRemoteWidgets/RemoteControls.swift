import AppIntents
import SwiftUI
import WidgetKit

// Control Center / Lock Screen controls (iOS 18+).

@available(iOS 18.0, *)
struct TVPowerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.akshay.BraviaRemote.control.power") {
            ControlWidgetButton(action: TVPowerIntent(action: .toggle)) {
                Label("TV Power", systemImage: "power")
            }
        }
        .displayName("TV Power")
        .description("Turn your BRAVIA on or off.")
    }
}

@available(iOS 18.0, *)
struct TVMuteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.akshay.BraviaRemote.control.mute") {
            ControlWidgetButton(action: MuteTVIntent()) {
                Label("Mute TV", systemImage: "speaker.slash.fill")
            }
        }
        .displayName("Mute TV")
        .description("Mute or unmute your BRAVIA.")
    }
}
