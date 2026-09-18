import Foundation

public final class CommandInterpreter {
    private let client: JevClient
    private let installedApps: [String]

    private static let browserNames: Set<String> = [
        "safari", "google chrome", "chrome", "firefox", "arc", "brave browser",
        "microsoft edge", "opera", "vivaldi", "orion", "duckduckgo",
    ]

    public init(client: JevClient, installedApps: [String]) {
        self.client = client
        self.installedApps = installedApps
    }

    struct State: Encodable {
        let clause: String
        let fullTranscript: String
        let frontmostApp: String?
        let installedApps: [String]

        enum CodingKeys: String, CodingKey {
            case clause
            case fullTranscript = "full_transcript"
            case frontmostApp = "frontmost_app"
            case installedApps = "installed_apps"
        }
    }

    public func interpret(transcript: String, frontmostApp: String?) async throws -> [Decision] {
        let clauses = ClauseSplitter.split(transcript)
        return try await withThrowingTaskGroup(of: (Int, Decision).self) { group in
            for (index, clause) in clauses.enumerated() {
                group.addTask {
                    let decision = try await self.interpretClause(
                        clause, transcript: transcript, frontmostApp: frontmostApp
                    )
                    return (index, decision)
                }
            }
            var ordered: [(Int, Decision)] = []
            for try await result in group { ordered.append(result) }
            return ordered.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    private func interpretClause(
        _ clause: String, transcript: String, frontmostApp: String?
    ) async throws -> Decision {
        var appCriteria: [String: String?] = ["none": "No application mentioned"]
        for app in installedApps.prefix(254) { appCriteria[app] = nil }

        var actionCriteria: [String: String?] = [:]
        for action in Action.allCases { actionCriteria[action.rawValue] = action.description }

        var systemCriteria: [String: String?] = [:]
        for action in SystemAction.allCases { systemCriteria[action.rawValue] = action.description }

        let questions: [String: Question] = [
            "action": .choice(
                instructions: "What action does this spoken command clause request? Clause: \"\(clause)\"",
                criteria: actionCriteria
            ),
            "target_app": .choice(
                instructions: "Which application does the clause refer to? Clause: \"\(clause)\"",
                criteria: appCriteria
            ),
            "system_action": .choice(
                instructions: "Which system action does the clause request? Clause: \"\(clause)\"",
                criteria: systemCriteria
            ),
            "mentions_url": .noul(
                instructions: "Does the clause \"\(clause)\" mention a website or URL?"
            ),
            "refers_to_frontmost": .noul(
                instructions: "Does the clause \"\(clause)\" refer to the currently active app rather than naming one?"
            ),
        ]

        let state = State(
            clause: clause,
            fullTranscript: transcript,
            frontmostApp: frontmostApp,
            installedApps: installedApps
        )
        let (response, latencyMs) = try await client.systemOne(state: state, questions: questions)

        var action = Action.none
        var actionProbs: [String: Double] = [:]
        var actionConfidence = 0.0
        if case .choice(let choice, let confidence, let probs) = response.answers["action"] {
            action = Action(rawValue: choice) ?? .none
            actionProbs = probs
            actionConfidence = confidence
        }

        var targetApp: String?
        var targetProbs: [String: Double] = [:]
        var targetConfidence = 1.0
        if case .choice(let choice, let confidence, let probs) = response.answers["target_app"] {
            targetProbs = probs
            targetConfidence = confidence
            if choice != "none" { targetApp = choice }
        }

        var systemAction: SystemAction?
        var systemConfidence = 1.0
        if case .choice(let choice, let confidence, _) = response.answers["system_action"] {
            systemConfidence = confidence
            let parsed = SystemAction(rawValue: choice) ?? .none
            if parsed != .none { systemAction = parsed }
        }

        var refersToFrontmost = false
        if case .noul(let p) = response.answers["refers_to_frontmost"] {
            refersToFrontmost = p > 0.5
        }

        let url = SlotExtractor.url(from: clause)
        var query = SlotExtractor.searchQuery(from: clause)
        let text = SlotExtractor.dictationText(from: clause)
        let percent = SlotExtractor.numberPercent(from: clause)

        if action == .openURL && url == nil, let q = query {
            action = .webSearch
            query = q
        }
        let localMatch = refersToFrontmost
            ? nil : AppMatcher.match(clause: clause, installedApps: installedApps)
        if let verbAction = AppMatcher.verbAction(clause: clause), let local = localMatch {
            action = verbAction
            actionConfidence = max(actionConfidence, 0.95)
            targetApp = local.app
            targetConfidence = local.confidence
            systemAction = nil
            systemConfidence = 1.0
        }
        if targetApp == nil && Action.appTargeted.contains(action) {
            if refersToFrontmost {
                if action != .openApp, let front = frontmostApp {
                    targetApp = front
                } else {
                    action = .none
                }
            } else if let local = localMatch {
                targetApp = local.app
                targetConfidence = local.confidence
            }
        }
        if (action == .openURL || action == .webSearch),
           let app = targetApp,
           !CommandInterpreter.browserNames.contains(app.lowercased()) {
            targetApp = nil
        }
        if action == .system && systemAction == nil {
            systemAction = SystemAction.none
        }
        if systemAction != nil && action == .none {
            action = .system
        }

        let confidence = min(actionConfidence, targetConfidence, systemConfidence)

        return Decision(
            clause: clause,
            action: action,
            actionProbabilities: actionProbs,
            targetApp: targetApp,
            targetAppProbabilities: targetProbs,
            systemAction: systemAction,
            url: url,
            query: query,
            text: text,
            percent: percent,
            confidence: confidence,
            latencyMs: latencyMs,
            model: response.model
        )
    }
}
