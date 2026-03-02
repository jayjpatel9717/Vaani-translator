import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAPIKeyText = false
    @State private var savedConfirmation = false

    private var theme: AppTheme { AppTheme(colorScheme) }

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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            VStack(spacing: 14) {
                // MARK: - API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API KEY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.sectionHeaderColor)

                    HStack(spacing: 6) {
                        if showAPIKeyText {
                            TextField("sk_...", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        } else {
                            SecureField("sk_...", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                        }

                        Button(action: { showAPIKeyText.toggle() }) {
                            Image(systemName: showAPIKeyText ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        Button(action: {
                            if let text = NSPasteboard.general.string(forType: .string) {
                                viewModel.apiKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }) {
                            Text("Paste")
                                .font(.system(size: 10))
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
                                .font(.system(size: 10))
                        }
                        .controlSize(.small)
                        .tint(savedConfirmation ? .green : nil)

                        Spacer()

                        Circle()
                            .fill(viewModel.hasAPIKey() ? theme.statusSuccess : theme.statusWarning)
                            .frame(width: 6, height: 6)
                        Text("Keychain")
                            .font(.system(size: 9))
                            .foregroundColor(theme.sectionHeaderColor)
                    }
                }

                Divider()

                // MARK: - Shortcuts
                VStack(alignment: .leading, spacing: 6) {
                    Text("SHORTCUTS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.sectionHeaderColor)

                    HStack {
                        Text("Hold to speak")
                            .font(.system(size: 11))
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .record)
                    }

                    Divider()

                    HStack {
                        Text("fn (globe) key")
                            .font(.system(size: 11))
                        Spacer()
                        Toggle("", isOn: $viewModel.useFnKey)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }

                    Divider()

                    HStack(spacing: 4) {
                        Text("Auto-paste")
                            .font(.system(size: 11))
                        Spacer()
                        Circle()
                            .fill(viewModel.accessibilityGranted ? theme.statusSuccess : theme.statusWarning)
                            .frame(width: 6, height: 6)
                        Text(viewModel.accessibilityGranted ? "On" : "Off")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        if !viewModel.accessibilityGranted {
                            Button("Grant") {
                                PasteboardManager.requestAccessibilityPermission()
                            }
                            .controlSize(.mini)
                        }
                    }
                }

                Divider()

                // MARK: - About
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.brandBlue)
                    Text("Vaani v1.0.0")
                        .font(.system(size: 11, weight: .medium))
                    Text("\u{00B7} Sarvam AI")
                        .font(.system(size: 10))
                        .foregroundColor(theme.sectionHeaderColor)
                    Spacer()
                }
            }
            .padding(16)

            Spacer()
        }
        .frame(width: 320, height: 380)
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
