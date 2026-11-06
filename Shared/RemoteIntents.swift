import AppIntents
import Foundation

// App Intents power Siri, the Shortcuts app, interactive widgets, Control Center controls
// and the buttons on the Lock Screen remote.
//
// The intents adopt `LiveActivityIntent`. The system then runs them in the app's own process
// (in the background, without opening the app), even when tapped from a widget or a
// Live Activity. That process already has the TV pairing and Local Network permission.

enum RemoteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noTV
    case appNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noTV: return "Pair a TV in Bravia Remote first."
        case .appNotFound(let name): return "Couldn't find an app called \(name) on the TV."
        }
    }
}

// MARK: - Entities & enums

struct TVEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "TV"
    static var defaultQuery = TVEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ tv: SavedTV) {
        id = tv.id
        name = tv.name
    }
}

struct TVEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TVEntity] {
        TVStore.load().tvs.filter { identifiers.contains($0.id) }.map(TVEntity.init)
    }

    func suggestedEntities() async throws -> [TVEntity] {
        TVStore.load().tvs.map(TVEntity.init)
    }

    func defaultResult() async -> TVEntity? {
        TVStore.currentTV().map(TVEntity.init)
    }
}

enum PowerAction: String, AppEnum {
    case on, off, toggle

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Power"
    static var caseDisplayRepresentations: [PowerAction: DisplayRepresentation] = [
        .on: "on",
        .off: "off",
        .toggle: "on or off"
    ]
}

enum TVButton: String, AppEnum {
    case volumeUp, volumeDown, mute, channelUp, channelDown
    case play, pause, rewind, fastForward
    case up, down, left, right, ok, back, home
    case input, guide, settings

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "TV Button"
    static var caseDisplayRepresentations: [TVButton: DisplayRepresentation] = [
        .volumeUp: "Volume Up",
        .volumeDown: "Volume Down",
        .mute: "Mute",
        .channelUp: "Channel Up",
        .channelDown: "Channel Down",
        .play: "Play",
        .pause: "Pause",
        .rewind: "Rewind",
        .fastForward: "Fast Forward",
        .up: "Up",
        .down: "Down",
        .left: "Left",
        .right: "Right",
        .ok: "OK",
        .back: "Back",
        .home: "Home",
        .input: "Input",
        .guide: "Guide",
        .settings: "Settings"
    ]

    var key: RemoteKey {
        switch self {
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .mute: return .mute
        case .channelUp: return .channelUp
        case .channelDown: return .channelDown
        case .play: return .play
        case .pause: return .pause
        case .rewind: return .rewind
        case .fastForward: return .forward
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .ok: return .confirm
        case .back: return .back
        case .home: return .home
        case .input: return .input
        case .guide: return .guide
        case .settings: return .actionMenu
        }
    }

    /// Spoken confirmation, e.g. "Volume Up".
    var spoken: String {
        switch self {
        case .volumeUp: return "Volume up"
        case .volumeDown: return "Volume down"
        case .mute: return "Mute toggled"
        case .channelUp: return "Channel up"
        case .channelDown: return "Channel down"
        case .play: return "Playing"
        case .pause: return "Paused"
        case .rewind: return "Rewinding"
        case .fastForward: return "Fast forwarding"
        case .ok: return "OK"
        case .back: return "Back"
        case .home: return "Home"
        case .input: return "Input"
        case .guide: return "Guide"
        case .settings: return "Settings"
        case .up, .down, .left, .right: return "Moved \(rawValue)"
        }
    }
}

enum HDMIPort: String, AppEnum {
    case hdmi1, hdmi2, hdmi3, hdmi4

    var number: Int {
        switch self {
        case .hdmi1: return 1
        case .hdmi2: return 2
        case .hdmi3: return 3
        case .hdmi4: return 4
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "HDMI Input"
    static var caseDisplayRepresentations: [HDMIPort: DisplayRepresentation] = [
        .hdmi1: "HDMI 1",
        .hdmi2: "HDMI 2",
        .hdmi3: "HDMI 3",
        .hdmi4: "HDMI 4"
    ]
}

// MARK: - Intents

struct TVPowerIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Turn TV On or Off"
    static var description = IntentDescription("Turns your BRAVIA on, off, or toggles it. Turning on from standby needs Remote Start enabled on the TV.")

    @Parameter(title: "Action", default: .toggle)
    var action: PowerAction

    @Parameter(title: "TV")
    var tv: TVEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Turn \(\.$tv) \(\.$action)")
    }

    init() {}

    init(action: PowerAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await RemoteCommandRunner.power(action, on: tv?.id)
        RemoteSignals.powerChanged(isOn: result.isOn)
        return .result(dialog: "\(result.tv.name) is \(result.isOn ? "on" : "off").")
    }
}

struct PressTVButtonIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Press TV Button"
    static var description = IntentDescription("Presses a remote button on your BRAVIA, one or more times.")

    @Parameter(title: "Button")
    var button: TVButton

    @Parameter(title: "Times", default: 1, inclusiveRange: (1, 30))
    var times: Int

    @Parameter(title: "TV")
    var tv: TVEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Press \(\.$button) \(\.$times) times on \(\.$tv)")
    }

    init() {}

    init(button: TVButton, times: Int = 1) {
        self.button = button
        self.times = times
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tv = try await RemoteCommandRunner.press(button.key, times: times, on: self.tv?.id)
        return .result(dialog: "\(button.spoken) on \(tv.name).")
    }
}

struct SwitchTVInputIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Switch TV Input"
    static var description = IntentDescription("Switches your BRAVIA to an HDMI input.")

    @Parameter(title: "Input", default: .hdmi1)
    var port: HDMIPort

    @Parameter(title: "TV")
    var tv: TVEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Switch \(\.$tv) to \(\.$port)")
    }

    init() {}

    init(port: HDMIPort) {
        self.port = port
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tv = try await RemoteCommandRunner.switchToHDMI(port.number, on: self.tv?.id)
        return .result(dialog: "Switched \(tv.name) to HDMI \(port.number).")
    }
}

struct OpenTVAppIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Open App on TV"
    static var description = IntentDescription("Opens an app on your BRAVIA by name, for example Netflix or YouTube.")

    @Parameter(title: "App name")
    var appName: String

    @Parameter(title: "TV")
    var tv: TVEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$appName) on \(\.$tv)")
    }

    init() {}

    init(appName: String) {
        self.appName = appName
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await RemoteCommandRunner.openApp(named: appName, on: tv?.id)
        return .result(dialog: "Opening \(result.title) on \(result.tv.name).")
    }
}

/// Lets intents tell the running app (and widgets) that something changed.
enum RemoteSignals {
    static let powerChangedNotification = Notification.Name("BraviaRemote.powerChanged")

    @MainActor
    static func powerChanged(isOn: Bool) {
        NotificationCenter.default.post(name: powerChangedNotification, object: nil, userInfo: ["isOn": isOn])
    }
}

// MARK: - One-tap intents (widgets, controls, Siri phrases)

struct TVVolumeUpIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "TV Volume Up"
    static var description = IntentDescription("Raises the TV volume.")

    @Parameter(title: "Steps", default: 1, inclusiveRange: (1, 30))
    var steps: Int

    init() {}

    init(steps: Int) {
        self.steps = steps
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tv = try await RemoteCommandRunner.press(.volumeUp, times: steps)
        return .result(dialog: "Turned \(tv.name) up.")
    }
}

struct TVVolumeDownIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "TV Volume Down"
    static var description = IntentDescription("Lowers the TV volume.")

    @Parameter(title: "Steps", default: 1, inclusiveRange: (1, 30))
    var steps: Int

    init() {}

    init(steps: Int) {
        self.steps = steps
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tv = try await RemoteCommandRunner.press(.volumeDown, times: steps)
        return .result(dialog: "Turned \(tv.name) down.")
    }
}

struct MuteTVIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Mute TV"
    static var description = IntentDescription("Mutes or unmutes the TV.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tv = try await RemoteCommandRunner.press(.mute)
        return .result(dialog: "Toggled mute on \(tv.name).")
    }
}
