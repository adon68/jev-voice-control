import AppKit
import ApplicationServices
import AVFoundation
import Speech

enum Permission: String, CaseIterable, Identifiable {
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    case accessibility = "Accessibility"

    var id: String { rawValue }

    var purpose: String {
        switch self {
        case .microphone: return "hear your commands"
        case .speechRecognition: return "transcribe them"
        case .accessibility: return "type dictated text"
        }
    }

    private var settingsAnchor: String {
        switch self {
        case .microphone: return "Privacy_Microphone"
        case .speechRecognition: return "Privacy_SpeechRecognition"
        case .accessibility: return "Privacy_Accessibility"
        }
    }

    var isGranted: Bool {
        switch self {
        case .microphone:
            if #available(macOS 14, *) {
                return AVAudioApplication.shared.recordPermission == .granted
            }
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .speechRecognition:
            return SFSpeechRecognizer.authorizationStatus() == .authorized
        case .accessibility:
            return AXIsProcessTrusted()
        }
    }

    /// Whether the system will still show its own prompt for this permission.
    var canPrompt: Bool {
        switch self {
        case .microphone:
            if #available(macOS 14, *) {
                return AVAudioApplication.shared.recordPermission == .undetermined
            }
            return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
        case .speechRecognition:
            return SFSpeechRecognizer.authorizationStatus() == .notDetermined
        case .accessibility:
            return true
        }
    }

    static var missing: [Permission] { allCases.filter { !$0.isGranted } }

    /// Triggers the system prompt where one is still available, otherwise opens System Settings.
    @MainActor
    func request() async {
        guard !isGranted else { return }
        guard canPrompt else {
            openSystemSettings()
            return
        }
        switch self {
        case .microphone:
            if #available(macOS 14, *) {
                _ = await AVAudioApplication.requestRecordPermission()
            } else {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
        case .speechRecognition:
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)")!
        NSWorkspace.shared.open(url)
    }
}
