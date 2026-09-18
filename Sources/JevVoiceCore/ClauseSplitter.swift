import Foundation

public enum ClauseSplitter {
    static let commandVerbs: Set<String> = [
        "open", "launch", "close", "quit", "go", "type", "write", "search",
        "google", "set", "turn", "mute", "unmute", "lock", "sleep", "take",
        "switch", "show", "hide", "play", "pause", "next", "previous",
    ]

    public static func split(_ transcript: String) -> [String] {
        let pattern = #"\b(and then|and also|then|and)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [transcript.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        let ns = transcript as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: transcript, range: fullRange)

        var splitLocations: [(start: Int, resume: Int)] = []
        for match in matches {
            let after = match.range.location + match.range.length
            guard after < ns.length else { continue }
            var i = after
            while i < ns.length, !ns.substring(with: NSRange(location: i, length: 1)).first!.isLetter {
                i += 1
                if i >= ns.length { break }
            }
            guard i < ns.length else { continue }
            var j = i
            while j < ns.length {
                let ch = ns.substring(with: NSRange(location: j, length: 1)).first!
                if ch.isLetter || ch.isNumber { j += 1 } else { break }
            }
            let nextWord = ns.substring(with: NSRange(location: i, length: j - i)).lowercased()
            if commandVerbs.contains(nextWord) {
                splitLocations.append((start: match.range.location, resume: i))
            }
        }

        var parts: [String] = []
        var last = 0
        for loc in splitLocations {
            let piece = ns.substring(with: NSRange(location: last, length: loc.start - last))
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { parts.append(trimmed) }
            last = loc.resume
        }
        let tail = ns.substring(from: last).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }
        return parts.isEmpty ? [transcript.trimmingCharacters(in: .whitespacesAndNewlines)] : parts
    }
}
