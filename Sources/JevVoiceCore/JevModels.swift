import Foundation

public enum Question: Encodable {
    case noul(instructions: String)
    case choice(instructions: String, criteria: [String: String?])
    case score(instructions: String, levels: [String])

    enum CodingKeys: String, CodingKey {
        case type, instructions, criteria
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .noul(let instructions):
            try container.encode("noul", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
        case .choice(let instructions, let criteria):
            try container.encode("choice", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
            try container.encode(criteria, forKey: .criteria)
        case .score(let instructions, let levels):
            try container.encode("score", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
            try container.encode(levels, forKey: .criteria)
        }
    }
}

public enum Answer: Decodable {
    case noul(Double)
    case choice(choice: String, confidence: Double, probabilities: [String: Double])
    case score(score: Double, confidence: Double, probabilities: [String: Double], legend: [String: String])

    enum CodingKeys: String, CodingKey {
        case type, noul, choice, confidence, probabilities, legend, score
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "noul":
            self = .noul(try container.decode(Double.self, forKey: .noul))
        case "choice":
            self = .choice(
                choice: try container.decode(String.self, forKey: .choice),
                confidence: try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0,
                probabilities: try container.decodeIfPresent([String: Double].self, forKey: .probabilities) ?? [:]
            )
        case "score":
            self = .score(
                score: try container.decode(Double.self, forKey: .score),
                confidence: try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0,
                probabilities: try container.decodeIfPresent([String: Double].self, forKey: .probabilities) ?? [:],
                legend: try container.decodeIfPresent([String: String].self, forKey: .legend) ?? [:]
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown answer type: \(type)"
            )
        }
    }
}

public struct Usage: Decodable {
    public let inputTokens: Int
    public let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

public struct SystemOneResponse: Decodable {
    public let model: String
    public let answers: [String: Answer]
    public let usage: Usage?
}

struct SystemOneRequest<State: Encodable>: Encodable {
    let model: String
    let state: State
    let questions: [String: Question]
}
