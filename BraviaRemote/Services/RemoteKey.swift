import Foundation

/// Remote keys. `rawValue` is the name the TV reports in `getRemoteControllerInfo`,
/// so the app prefers the TV's own codes and only uses `fallbackCode` if that lookup fails.
enum RemoteKey: String, CaseIterable {
    case power = "TvPower"
    case powerOff = "PowerOff"
    case wakeUp = "WakeUp"
    case tv = "Tv"
    case input = "Input"
    case home = "Home"
    case back = "Return"
    case options = "Options"
    case actionMenu = "ActionMenu"
    case guide = "GGuide"
    case display = "Display"
    case subtitle = "SubTitle"
    case help = "Help"

    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case confirm = "Confirm"

    case volumeUp = "VolumeUp"
    case volumeDown = "VolumeDown"
    case mute = "Mute"
    case channelUp = "ChannelUp"
    case channelDown = "ChannelDown"

    case play = "Play"
    case pause = "Pause"
    case stop = "Stop"
    case rewind = "Rewind"
    case forward = "Forward"
    case prev = "Prev"
    case next = "Next"

    case netflix = "Netflix"
    case youtube = "YouTube"

    case red = "Red"
    case green = "Green"
    case yellow = "Yellow"
    case blue = "Blue"

    case num0 = "Num0", num1 = "Num1", num2 = "Num2", num3 = "Num3", num4 = "Num4"
    case num5 = "Num5", num6 = "Num6", num7 = "Num7", num8 = "Num8", num9 = "Num9"

    static func number(_ n: Int) -> RemoteKey {
        [.num0, .num1, .num2, .num3, .num4, .num5, .num6, .num7, .num8, .num9][max(0, min(9, n))]
    }

    /// Standard Sony IRCC codes (Base64). Used only when the TV's code list is unavailable.
    var fallbackCode: String {
        switch self {
        case .power: return "AAAAAQAAAAEAAAAVAw=="
        case .powerOff: return "AAAAAQAAAAEAAAAvAw=="
        case .wakeUp: return "AAAAAQAAAAEAAAAuAw=="
        case .tv: return "AAAAAQAAAAEAAAAkAw=="
        case .input: return "AAAAAQAAAAEAAAAlAw=="
        case .home: return "AAAAAQAAAAEAAABgAw=="
        case .back: return "AAAAAgAAAJcAAAAjAw=="
        case .options: return "AAAAAgAAAJcAAAA2Aw=="
        case .actionMenu: return "AAAAAgAAAMQAAABLAw=="
        case .guide: return "AAAAAQAAAAEAAAAOAw=="
        case .display: return "AAAAAQAAAAEAAAA6Aw=="
        case .subtitle: return "AAAAAgAAAJcAAAAoAw=="
        case .help: return "AAAAAgAAAMQAAABNAw=="
        case .up: return "AAAAAQAAAAEAAAB0Aw=="
        case .down: return "AAAAAQAAAAEAAAB1Aw=="
        case .left: return "AAAAAQAAAAEAAAA0Aw=="
        case .right: return "AAAAAQAAAAEAAAAzAw=="
        case .confirm: return "AAAAAQAAAAEAAABlAw=="
        case .volumeUp: return "AAAAAQAAAAEAAAASAw=="
        case .volumeDown: return "AAAAAQAAAAEAAAATAw=="
        case .mute: return "AAAAAQAAAAEAAAAUAw=="
        case .channelUp: return "AAAAAQAAAAEAAAAQAw=="
        case .channelDown: return "AAAAAQAAAAEAAAARAw=="
        case .play: return "AAAAAgAAAJcAAAAaAw=="
        case .pause: return "AAAAAgAAAJcAAAAZAw=="
        case .stop: return "AAAAAgAAAJcAAAAYAw=="
        case .rewind: return "AAAAAgAAAJcAAAAbAw=="
        case .forward: return "AAAAAgAAAJcAAAAcAw=="
        case .prev: return "AAAAAgAAAJcAAAA8Aw=="
        case .next: return "AAAAAgAAAJcAAAA9Aw=="
        case .netflix: return "AAAAAgAAABoAAAB8Aw=="
        case .youtube: return "AAAAAgAAAMQAAABHAw=="
        case .red: return "AAAAAgAAAJcAAAAlAw=="
        case .green: return "AAAAAgAAAJcAAAAmAw=="
        case .yellow: return "AAAAAgAAAJcAAAAnAw=="
        case .blue: return "AAAAAgAAAJcAAAAkAw=="
        case .num1: return "AAAAAQAAAAEAAAAAAw=="
        case .num2: return "AAAAAQAAAAEAAAABAw=="
        case .num3: return "AAAAAQAAAAEAAAACAw=="
        case .num4: return "AAAAAQAAAAEAAAADAw=="
        case .num5: return "AAAAAQAAAAEAAAAEAw=="
        case .num6: return "AAAAAQAAAAEAAAAFAw=="
        case .num7: return "AAAAAQAAAAEAAAAGAw=="
        case .num8: return "AAAAAQAAAAEAAAAHAw=="
        case .num9: return "AAAAAQAAAAEAAAAIAw=="
        case .num0: return "AAAAAQAAAAEAAAAJAw=="
        }
    }
}
