import AppKit
import JevVoiceCore
import SwiftUI

@MainActor
final class VoiceController: ObservableObject {
    enum Status: Equatable {
        case idle, listening, thinking, awaitingConfirm, executing, done
        case error(String)
    }

    @Published var status: Status = .idle
    @Published var transcript = ""
    @Published var decisions: [Decision] = []
    @Published var latencyMs: Double = 0
    @Published var model = ""
    @Published var history: [Decision] = []
    @Published var showSettings = false

    let config = Config.shared
    let recognizer = SpeechRecognizer()

    var onListeningChanged: ((Bool) -> Void)?
    var onDone: (() -> Void)?

    private var apps: [String] = []

    init() {
        recognizer.onFinalTranscript = { [weak self] text in
            Task { @MainActor in await self?.interpretAndExecute(text) }
        }
    }

    func toggle() {
        switch status {
        case .listening:
            recognizer.stop()
        case .idle, .done, .error:
            startListening()
        default:
            break
        }
    }

    func startListening() {
        Task {
            guard await SpeechRecognizer.requestAuthorization() else {
                status = .error("Microphone or Speech Recognition permission denied")
                return
            }
            do {
                decisions = []
                transcript = ""
                try recognizer.start()
                status = .listening
                onListeningChanged?(true)
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    private func interpretAndExecute(_ text: String) async {
        status = .thinking
        onListeningChanged?(false)
        transcript = text

        if apps.isEmpty { apps = InstalledApps.all() }
        let client = JevClient(apiKey: config.apiKey)
        let interpreter = CommandInterpreter(client: client, installedApps: apps)
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName

        do {
            var result = try await interpreter.interpret(transcript: text, frontmostApp: frontmost)
            latencyMs = result.map(\.latencyMs).max() ?? 0
            model = result.first?.model ?? ""
            for i in result.indices { result[i].latencyMs = latencyMs }
            decisions = result
            history = (result + history).prefix(10).map { $0 }
        } catch {
            status = .error(error.localizedDescription)
            return
        }

        if config.autoExecute && decisions.allSatisfy({ $0.confidence >= config.confidenceThreshold || $0.action == .none }) {
            await executeAll()
        } else {
            status = .awaitingConfirm
            onDone?()
        }
    }

    func confirmAndExecute() async {
        await executeAll()
    }

    private func executeAll() async {
        let actionable = decisions.filter { $0.action != .none }
        guard !actionable.isEmpty else {
            status = .done
            onDone?()
            return
        }
        status = .executing
        for decision in actionable {
            do {
                _ = try await Executor.execute(decision)
            } catch {
                status = .error(error.localizedDescription)
                return
            }
        }
        status = .done
        onDone?()
    }
}
