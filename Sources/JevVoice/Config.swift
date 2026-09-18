import Foundation

final class Config: ObservableObject {
    static let shared = Config()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "typesafeAPIKey") }
    }

    @Published var confidenceThreshold: Double {
        didSet { UserDefaults.standard.set(confidenceThreshold, forKey: "confidenceThreshold") }
    }

    @Published var autoExecute: Bool {
        didSet { UserDefaults.standard.set(autoExecute, forKey: "autoExecute") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.apiKey = defaults.string(forKey: "typesafeAPIKey")
            ?? ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]
            ?? ""
        self.confidenceThreshold = defaults.object(forKey: "confidenceThreshold") == nil
            ? 0.7
            : defaults.double(forKey: "confidenceThreshold")
        self.autoExecute = defaults.object(forKey: "autoExecute") as? Bool ?? true
    }
}
