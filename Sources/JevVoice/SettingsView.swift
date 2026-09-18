import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var controller: VoiceController
    @ObservedObject private var config = Config.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { controller.showSettings = false }
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("TypeSafe API key").font(.caption)
                SecureField("ts-…", text: $config.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Confidence threshold: \(Int(config.confidenceThreshold * 100))%")
                    .font(.caption)
                Slider(value: $config.confidenceThreshold, in: 0...1)
            }

            Toggle("Auto-execute high-confidence decisions", isOn: $config.autoExecute)
                .font(.caption)

            Spacer()
        }
    }
}
