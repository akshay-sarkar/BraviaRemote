import AppIntents

/// Siri phrases and Shortcuts-app tiles. Works with "Hey Siri" and the Action button
/// without any setup. Every phrase must include the app name.
struct BraviaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TVPowerIntent(),
            phrases: [
                "Turn \(\.$action) the TV with \(.applicationName)",
                "Turn \(\.$action) my TV with \(.applicationName)",
                "Switch the TV \(\.$action) with \(.applicationName)"
            ],
            shortTitle: "TV Power",
            systemImageName: "power"
        )
        AppShortcut(
            intent: MuteTVIntent(),
            phrases: [
                "Mute the TV with \(.applicationName)",
                "Unmute the TV with \(.applicationName)"
            ],
            shortTitle: "Mute TV",
            systemImageName: "speaker.slash.fill"
        )
        AppShortcut(
            intent: TVVolumeUpIntent(steps: 3),
            phrases: [
                "Turn up the TV with \(.applicationName)",
                "TV louder with \(.applicationName)"
            ],
            shortTitle: "TV Louder",
            systemImageName: "speaker.wave.3.fill"
        )
        AppShortcut(
            intent: TVVolumeDownIntent(steps: 3),
            phrases: [
                "Turn down the TV with \(.applicationName)",
                "TV quieter with \(.applicationName)"
            ],
            shortTitle: "TV Quieter",
            systemImageName: "speaker.wave.1.fill"
        )
        AppShortcut(
            intent: PressTVButtonIntent(),
            phrases: [
                "Press \(\.$button) on the TV with \(.applicationName)",
                "\(.applicationName) \(\.$button)"
            ],
            shortTitle: "TV Button",
            systemImageName: "av.remote"
        )
        AppShortcut(
            intent: SwitchTVInputIntent(),
            phrases: [
                "Switch the TV to \(\.$port) with \(.applicationName)",
                "Change the TV input to \(\.$port) with \(.applicationName)"
            ],
            shortTitle: "Switch Input",
            systemImageName: "rectangle.on.rectangle"
        )
        AppShortcut(
            intent: OpenTVAppIntent(),
            phrases: [
                "Open an app on the TV with \(.applicationName)"
            ],
            shortTitle: "Open TV App",
            systemImageName: "square.grid.2x2"
        )
    }
}
