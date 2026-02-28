import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel

    @State private var showAPIKeyText = false
    @State private var savedConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: { viewModel.showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - API
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabelColor))
                            .textCase(.uppercase)

                        VStack(spacing: 10) {
                            SettingsRow(label: "Provider") {
                                Text("Sarvam AI")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Key")
                                    .font(.system(size: 12, weight: .medium))

                                HStack(spacing: 6) {
                                    if showAPIKeyText {
                                        TextField("sk_...", text: $viewModel.apiKey)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))
                                    } else {
                                        SecureField("sk_...", text: $viewModel.apiKey)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12))
                                    }

                                    Button(action: { showAPIKeyText.toggle() }) {
                                        Image(systemName: showAPIKeyText ? "eye.slash" : "eye")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    Button(action: {
                                        if let text = NSPasteboard.general.string(forType: .string) {
                                            viewModel.apiKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                    }) {
                                        Text("Paste")
                                            .font(.system(size: 11))
                                    }
                                    .controlSize(.small)

                                    Button(action: {
                                        viewModel.saveAPIKey()
                                        savedConfirmation = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            savedConfirmation = false
                                        }
                                    }) {
                                        Text(savedConfirmation ? "Saved" : "Save")
                                            .font(.system(size: 11))
                                    }
                                    .controlSize(.small)
                                    .tint(savedConfirmation ? .green : nil)

                                    Spacer()

                                    Circle()
                                        .fill(viewModel.hasAPIKey() ? Color.green : Color.orange)
                                        .frame(width: 7, height: 7)
                                }

                                Text("Stored securely in macOS Keychain")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(.tertiaryLabelColor))
                            }
                        }
                    }

                    Divider()

                    // MARK: - Shortcuts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shortcuts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabelColor))
                            .textCase(.uppercase)

                        VStack(spacing: 10) {
                            SettingsRow(label: "Hold to speak") {
                                KeyboardShortcuts.Recorder("", name: .record)
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use fn (globe) key")
                                        .font(.system(size: 12))
                                    Text("Hold to record, release to translate")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(.tertiaryLabelColor))
                                }
                                Spacer()
                                Toggle("", isOn: $viewModel.useFnKey)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                            }

                            Divider()

                            HStack(spacing: 6) {
                                Text("Auto-paste")
                                    .font(.system(size: 12))
                                Spacer()
                                Circle()
                                    .fill(viewModel.accessibilityGranted ? Color.green : Color.orange)
                                    .frame(width: 7, height: 7)
                                Text(viewModel.accessibilityGranted ? "Enabled" : "Needs permission")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                if !viewModel.accessibilityGranted {
                                    Button("Grant") {
                                        PasteboardManager.requestAccessibilityPermission()
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                    }

                    Divider()

                    // MARK: - Modes Guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Modes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabelColor))
                            .textCase(.uppercase)

                        VStack(spacing: 0) {
                            ModeInfoRow(
                                name: "Transcribe",
                                desc: "Writes what you say in the original language",
                                example: "\u{092E}\u{0947}\u{0930}\u{093E} \u{092B}\u{094B}\u{0928} \u{0928}\u{0902}\u{092C}\u{0930} \u{0939}\u{0948} 9840950950",
                                isFirst: true
                            )
                            ModeInfoRow(
                                name: "Translate",
                                desc: "Converts your speech into another language",
                                example: "My phone number is 9840950950"
                            )
                            ModeInfoRow(
                                name: "Transliterate",
                                desc: "Writes your speech in English letters",
                                example: "mera phone number hai 9840950950"
                            )
                            ModeInfoRow(
                                name: "Code-mix",
                                desc: "English stays English, rest in native script",
                                example: "\u{092E}\u{0947}\u{0930}\u{093E} phone number \u{0939}\u{0948} 9840950950"
                            )
                            ModeInfoRow(
                                name: "Verbatim",
                                desc: "Exact words as spoken, no cleanup",
                                example: "\u{092E}\u{0947}\u{0930}\u{093E} \u{092B}\u{094B}\u{0928} \u{0928}\u{0902}\u{092C}\u{0930} \u{0939}\u{0948} \u{0928}\u{094C} \u{0906}\u{0920} \u{091A}\u{093E}\u{0930} zero..."
                            )
                        }
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    Divider()

                    // MARK: - About
                    HStack(spacing: 8) {
                        if let iconImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.resourcePath.map { $0 + "/AppIcon.icns" } ?? "") {
                            Image(nsImage: iconImage)
                                .resizable()
                                .frame(width: 36, height: 36)
                                .cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vaani v1.0.0")
                                .font(.system(size: 12, weight: .medium))
                            Text("23 languages \u{00B7} 5 modes \u{00B7} Uses Sarvam AI")
                                .font(.system(size: 10))
                                .foregroundColor(Color(.tertiaryLabelColor))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 500)
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            content
        }
    }
}

struct ModeInfoRow: View {
    let name: String
    let desc: String
    let example: String
    var isFirst: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider().padding(.leading, 10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(example)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabelColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
