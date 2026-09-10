import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showKey = false
    @State private var editingKey = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings").font(.glass(20, .heavy)).foregroundColor(theme.ink)
                    Text("Vaani 1.1 \u{00B7} Sarvam AI").font(.glass(11, .semibold)).foregroundColor(theme.secondary)
                }
                Spacer()
                IconCircleButton(systemName: "xmark", theme: theme) { viewModel.showSettings = false }
            }
            Spacer().frame(height: 14)

            VStack(spacing: 8) {
                keyCard
                row("Hold to speak", sub: "Click to record a new shortcut") {
                    KeyboardShortcuts.Recorder(for: .record).controlSize(.small)
                }
                row("fn / globe key", sub: "Hold fn anywhere to speak") {
                    Toggle("", isOn: $viewModel.useFnKey).toggleStyle(.switch).controlSize(.small).labelsHidden().tint(AppTheme.violet)
                }
                row("Type for me", sub: viewModel.accessibilityGranted ? "Accessibility granted" : "Needs Accessibility permission") {
                    if viewModel.accessibilityGranted {
                        StatusChip(text: "On", color: AppTheme.mint, textColor: theme.successText)
                    } else {
                        PillButton(title: "Grant", primary: true, theme: theme) {
                            PasteboardManager.requestAccessibilityPermission()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                row("Appearance", sub: nil) {
                    GlassSegmented(items: AppearanceMode.allCases.map { ($0, $0.displayName) }, selection: $viewModel.appearanceMode, theme: theme, height: 22)
                        .frame(width: 150)
                }
            }

            Spacer()

            HStack {
                Button("Run setup again") {
                    viewModel.setupCompleted = false
                    viewModel.showSettings = false
                }
                .buttonStyle(.plain)
                Spacer()
                Link(destination: URL(string: "https://dashboard.sarvam.ai")!) {
                    HStack(spacing: 3) {
                        Text("Sarvam dashboard")
                        Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(AppTheme.violet)
                }
            }
            .font(.glass(10, .bold))
            .foregroundColor(theme.secondary)
        }
    }

    private var keyCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").font(.system(size: 11, weight: .semibold)).foregroundColor(theme.secondary)
                if editingKey || viewModel.apiKey.isEmpty {
                    Group {
                        if showKey {
                            TextField("sk_...", text: $viewModel.apiKey)
                        } else {
                            SecureField("sk_...", text: $viewModel.apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.ink)
                } else {
                    Text(maskedKey).font(.system(size: 11, design: .monospaced)).tracking(1).foregroundColor(theme.secondary).lineLimit(1)
                    Spacer()
                }
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye").font(.system(size: 11)).foregroundColor(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                StatusChip(text: statusText, color: statusColor, textColor: statusTextColor)
                Spacer()
                Link("Get a key", destination: URL(string: "https://dashboard.sarvam.ai/key-management")!)
                    .font(.glass(10, .bold)).foregroundColor(AppTheme.violet)
                if editingKey || viewModel.apiKey.isEmpty {
                    PillButton(title: "Paste", theme: theme) {
                        if let text = NSPasteboard.general.string(forType: .string) {
                            viewModel.apiKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    PillButton(title: "Save", primary: true, theme: theme) {
                        viewModel.saveAPIKey()
                        editingKey = false
                    }
                } else {
                    PillButton(title: "Replace", theme: theme) { editingKey = true }
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .glassCard(theme)
    }

    private var maskedKey: String {
        let key = viewModel.apiKey
        let tail = key.count > 4 ? String(key.suffix(4)) : ""
        return "sk_\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022} \(tail)"
    }

    private var statusText: String {
        viewModel.apiKeyStatus == .unknown && viewModel.apiKey.isEmpty ? "No key saved" : viewModel.apiKeyStatus.label
    }

    private var statusColor: Color {
        switch viewModel.apiKeyStatus {
        case .ok: return AppTheme.mint
        case .invalid, .noCredits: return AppTheme.amber
        case .missing, .unknown: return theme.tertiary
        }
    }

    private var statusTextColor: Color {
        switch viewModel.apiKeyStatus {
        case .ok: return theme.successText
        case .invalid, .noCredits: return theme.warningText
        case .missing, .unknown: return theme.secondary
        }
    }

    private func row<Right: View>(_ label: String, sub: String?, @ViewBuilder right: () -> Right) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.glass(12, .bold)).foregroundColor(theme.ink)
                if let sub {
                    Text(sub).font(.glass(10, .semibold)).foregroundColor(theme.secondary)
                }
            }
            Spacer()
            right()
        }
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
        .glassCard(theme)
    }
}
