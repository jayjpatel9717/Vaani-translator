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

            ScrollView {
                VStack(spacing: 18) {
                    // MARK: - Appearance
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Appearance")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.sectionHeaderColor)
                            .textCase(.uppercase)

                        HStack(spacing: 6) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button(action: { viewModel.appearanceMode = mode }) {
                                    VStack(spacing: 3) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 13))
                                        Text(mode.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.appearanceMode == mode
                                            ? theme.brandBlue.opacity(0.12)
                                            : theme.cardBackground
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                viewModel.appearanceMode == mode
                                                    ? theme.brandBlue.opacity(0.5)
                                                    : theme.cardBorder,
                                                lineWidth: 1
                                            )
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(viewModel.appearanceMode == mode ? theme.brandBlue : .secondary)
                            }
                        }
                    }

                    Divider()

                    // MARK: - API
                    VStack(alignment: .leading, spacing: 10) {
                        Text("API")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.sectionHeaderColor)
                            .textCase(.uppercase)

                        VStack(spacing: 8) {
                            SettingsRow(label: "Provider") {
                                Text("Sarvam AI")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
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
                                        .fill(viewModel.hasAPIKey() ? theme.statusSuccess : theme.statusWarning)
                                        .frame(width: 7, height: 7)
                                }

                                Text("Stored securely in macOS Keychain")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.sectionHeaderColor)
                            }
                        }
                    }

                    Divider()

                    // MARK: - Shortcuts
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shortcuts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.sectionHeaderColor)
                            .textCase(.uppercase)

                        VStack(spacing: 8) {
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
                                        .foregroundColor(theme.sectionHeaderColor)
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
                                    .fill(viewModel.accessibilityGranted ? theme.statusSuccess : theme.statusWarning)
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

                    // MARK: - About
                    HStack(spacing: 8) {
                        if let iconImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.resourcePath.map { $0 + "/AppIcon.icns" } ?? "") {
                            Image(nsImage: iconImage)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .cornerRadius(7)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vaani v1.0.0")
                                .font(.system(size: 12, weight: .medium))
                            Text("23 languages \u{00B7} 5 modes \u{00B7} Sarvam AI")
                                .font(.system(size: 10))
                                .foregroundColor(theme.sectionHeaderColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
        }
        .frame(width: 340, height: 400)
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
