import Foundation

public enum SlotExtractor {
    private static let urlPattern = #"[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|ai|dev|co|app|pl|me|gg|tv|edu|gov|uk|de)(/\S*)?"#

    public static func url(from clause: String) -> String? {
        var s = " " + clause.lowercased() + " "
        s = s.replacingOccurrences(of: "w w w", with: "www")
        s = s.replacingOccurrences(of: " dot ", with: ".")
        s = s.replacingOccurrences(of: " slash ", with: "/")
        s = s.replacingOccurrences(of: " colon ", with: ":")
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return nil }
        let range = NSRange(location: 0, length: (s as NSString).length)
        guard let match = regex.firstMatch(in: s, range: range) else { return nil }
        var host = (s as NSString).substring(with: match.range)
        while host.hasSuffix(".") || host.hasSuffix(",") { host = String(host.dropLast()) }
        return "https://" + host
    }

    public static func searchQuery(from clause: String) -> String? {
        let lowered = clause.lowercased()
        let triggers = ["search for", "look up", "search", "google", "find"]
        var best: Range<String.Index>?
        for trigger in triggers {
            if let range = lowered.range(of: #"\b"# + trigger + #"\b"#, options: .regularExpression) {
                if best == nil || range.lowerBound < best!.lowerBound { best = range }
            }
        }
        guard let range = best else { return nil }
        let query = clause[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    public static func dictationText(from clause: String) -> String? {
        let lowered = clause.lowercased()
        guard let range = lowered.range(
            of: #"\b(type|write|dictate|say)\b"#, options: .regularExpression
        ) else { return nil }
        let text = clause[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    public static func numberPercent(from clause: String) -> Int? {
        let lowered = clause.lowercased()
        if let regex = try? NSRegularExpression(pattern: #"\b(\d{1,3})\b"#),
           let match = regex.firstMatch(in: lowered, range: NSRange(location: 0, length: (lowered as NSString).length)),
           let value = Int((lowered as NSString).substring(with: match.range(at: 1))),
           (0...100).contains(value) {
            return value
        }
        if lowered.range(of: #"\b(max|maximum|full)\b"#, options: .regularExpression) != nil { return 100 }
        if lowered.range(of: #"\bhalf\b"#, options: .regularExpression) != nil { return 50 }
        if lowered.range(of: #"\boff\b"#, options: .regularExpression) != nil { return 0 }
        return nil
    }
}
