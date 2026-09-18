import Foundation

public enum JevError: Error, LocalizedError {
    case http(status: Int, body: String)
    case transport(Error)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .http(let status, let body):
            return "Jev API error \(status): \(body)"
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .decoding(let error):
            return "Failed to decode Jev response: \(error.localizedDescription)"
        }
    }
}

public final class JevClient {
    public let apiKey: String
    public let baseURL: URL
    public let model: String
    private let session: URLSession

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
        model: String = "jev-latest",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    @discardableResult
    public func systemOne<State: Encodable>(
        state: State,
        questions: [String: Question]
    ) async throws -> (response: SystemOneResponse, latencyMs: Double) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SystemOneRequest(model: model, state: state, questions: questions)
        )

        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw JevError.transport(error)
        }
        let latencyMs = Date().timeIntervalSince(start) * 1000

        guard let http = response as? HTTPURLResponse else {
            throw JevError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw JevError.http(status: http.statusCode, body: body)
        }
        do {
            let decoded = try JSONDecoder().decode(SystemOneResponse.self, from: data)
            return (decoded, latencyMs)
        } catch {
            throw JevError.decoding(error)
        }
    }
}
