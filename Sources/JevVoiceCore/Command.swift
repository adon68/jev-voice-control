import Foundation

public enum Action: String, CaseIterable, Codable {
    case openApp, closeApp, openURL, webSearch, dictate, system, none

    public var description: String {
        switch self {
        case .openApp: return "Open or launch an application"
        case .closeApp: return "Close, quit, or exit an application"
        case .openURL: return "Open a specific website or URL in a browser"
        case .webSearch: return "Search the web for a query"
        case .dictate: return "Type or write text at the cursor"
        case .system: return "A system-level action (volume, lock, sleep, screenshot, brightness, show desktop)"
        case .none: return "No actionable command"
        }
    }
}

public enum SystemAction: String, CaseIterable, Codable {
    case volumeSet, mute, unmute, volumeUp, volumeDown
    case lockScreen, sleep, screenshot
    case brightnessUp, brightnessDown, showDesktop
    case none

    public var description: String {
        switch self {
        case .volumeSet: return "Set volume to a specific level"
        case .mute: return "Mute audio"
        case .unmute: return "Unmute audio"
        case .volumeUp: return "Increase volume"
        case .volumeDown: return "Decrease volume"
        case .lockScreen: return "Lock the screen"
        case .sleep: return "Put the computer to sleep"
        case .screenshot: return "Take a screenshot"
        case .brightnessUp: return "Increase display brightness"
        case .brightnessDown: return "Decrease display brightness"
        case .showDesktop: return "Show the desktop"
        case .none: return "No system action"
        }
    }
}

public struct Decision {
    public let clause: String
    public var action: Action
    public var actionProbabilities: [String: Double]
    public var targetApp: String?
    public var targetAppProbabilities: [String: Double]
    public var systemAction: SystemAction?
    public var url: String?
    public var query: String?
    public var text: String?
    public var percent: Int?
    public var confidence: Double
    public var latencyMs: Double
    public var model: String

    public init(
        clause: String,
        action: Action,
        actionProbabilities: [String: Double] = [:],
        targetApp: String? = nil,
        targetAppProbabilities: [String: Double] = [:],
        systemAction: SystemAction? = nil,
        url: String? = nil,
        query: String? = nil,
        text: String? = nil,
        percent: Int? = nil,
        confidence: Double = 0,
        latencyMs: Double = 0,
        model: String = ""
    ) {
        self.clause = clause
        self.action = action
        self.actionProbabilities = actionProbabilities
        self.targetApp = targetApp
        self.targetAppProbabilities = targetAppProbabilities
        self.systemAction = systemAction
        self.url = url
        self.query = query
        self.text = text
        self.percent = percent
        self.confidence = confidence
        self.latencyMs = latencyMs
        self.model = model
    }
}
