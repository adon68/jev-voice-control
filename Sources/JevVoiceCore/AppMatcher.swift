import Foundation

public enum AppMatcher {
    private static let stopWords: Set<String> = [
        "open", "close", "quit", "launch", "start", "kill", "exit", "switch", "to", "the",
        "app", "application", "please", "and", "then", "up", "my", "a", "an", "it",
    ]

    /// Finds the installed app most plausibly named in `clause`, e.g. "close chrome" -> "Google Chrome".
    public static func match(clause: String, installedApps: [String]) -> String? {
        let lowered = clause.lowercased()
        let words = tokens(lowered).filter { !stopWords.contains($0) }
        guard !words.isEmpty else { return nil }

        var best: (app: String, score: Int)?
        for app in installedApps {
            let appLowered = app.lowercased()
            let appTokens = tokens(appLowered)
            var score = 0
            if lowered.contains(appLowered) { score += 10 * appTokens.count }
            for word in words {
                if appTokens.contains(word) {
                    score += 4
                } else if word.count >= 4, appTokens.contains(where: { $0.hasPrefix(word) }) {
                    score += 2
                }
            }
            guard score > 0 else { continue }
            if best == nil || score > best!.score
                || (score == best!.score && app.count < best!.app.count) {
                best = (app, score)
            }
        }
        return best?.app
    }

    private static func tokens(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
