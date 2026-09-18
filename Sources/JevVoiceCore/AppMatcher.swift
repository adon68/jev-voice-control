import Foundation

public enum AppMatcher {
    public struct Match: Equatable {
        public let app: String
        /// 0.95 for an unambiguous full-name match, 0.8 for a token match, 0.5 when the best two candidates tie.
        public let confidence: Double
    }

    private static let stopWords: Set<String> = [
        "open", "close", "quit", "launch", "start", "kill", "exit", "switch", "to", "the",
        "app", "application", "please", "and", "then", "up", "my", "a", "an", "it",
    ]

    /// Finds the installed app most plausibly named in `clause`, e.g. "close chrome" -> "Google Chrome".
    public static func match(clause: String, installedApps: [String]) -> Match? {
        let clauseTokens = tokens(clause.lowercased())
        let words = clauseTokens.filter { !stopWords.contains($0) }
        guard !words.isEmpty else { return nil }

        var scored: [(app: String, score: Int, full: Bool)] = []
        for app in installedApps {
            let appTokens = tokens(app.lowercased())
            guard !appTokens.isEmpty else { continue }
            var score = 0
            let full = containsSequence(clauseTokens, appTokens)
            if full { score += 10 * appTokens.count }
            for word in words {
                if appTokens.contains(word) {
                    score += 4
                } else if word.count >= 4, appTokens.contains(where: { $0.hasPrefix(word) }) {
                    score += 2
                }
            }
            if score > 0 { scored.append((app, score, full)) }
        }
        scored.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.app.count < $1.app.count
        }
        guard let best = scored.first else { return nil }
        if scored.count > 1, scored[1].score == best.score {
            return Match(app: best.app, confidence: 0.5)
        }
        return Match(app: best.app, confidence: best.full ? 0.95 : 0.8)
    }

    private static func containsSequence(_ haystack: [String], _ needle: [String]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        return (0...(haystack.count - needle.count)).contains {
            Array(haystack[$0..<($0 + needle.count)]) == needle
        }
    }

    private static func tokens(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
