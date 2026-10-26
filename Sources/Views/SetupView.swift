import SwiftUI
import AppKit

/// First-run checklist: key, microphone, accessibility, try it.
struct SetupView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    private var keyDone: Bool { viewModel.apiKeyStatus == .ok }
    private var tried: Bool { !viewModel.lastResult.isEmpty }
    private var doneCount: Int { [keyDone, viewModel.micGranted, viewModel.accessibilityGranted, tried].filter { $0 }.count }
    private var allDone: Bool { doneCount == 4 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Welcome").font(.glass(20, .heavy)).foregroundColor(theme.ink)
                    Text("Four quick steps, then speak").font(.glass(11, .semibold)).foregroundColor(theme.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule().fill(i < doneCount ? AppTheme.mint : theme.ink.opacity(0.10)).frame(width: 18, height: 6)
                    }
                }
            }
            Spacer().frame(height: 16)

            VStack(spacing: 8) {
                step(1, "Sarvam API key", sub: keyDone ? "Key OK \u{00B7} saved to your keychain" : keySub, done: keyDone) {
                    if !keyDone {
                        HStack(spacing: 6) {
                            SecureField("sk_...", text: $viewModel.apiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(theme.ink)
                                .padding(.horizontal, 8).frame(height: 24)
                                .background(theme.segmentTrack)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            PillButton(title: "Save", primary: true, theme: theme) { viewModel.saveAPIKey() }
                        }
                        Link("Get a key at dashboard.sarvam.ai", destination: URL(string: "https://dashboard.sarvam.ai/key-management")!)
                            .font(.glass(10, .bold)).foregroundColor(AppTheme.violet)
                    }
                }
                step(2, "Microphone", sub: viewModel.micGranted ? "Allowed" : "So Vaani can hear you", done: viewModel.micGranted) {
                    PillButton(title: "Allow", theme: theme) { viewModel.requestMicPermission() }
                }
                step(3, "Accessibility", sub: viewModel.accessibilityGranted ? "Granted" : "So Vaani can type where your cursor is", done: viewModel.accessibilityGranted) {
                    PillButton(title: "Open Settings", primary: true, theme: theme) {
                        PasteboardManager.requestAccessibilityPermission()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                step(4, "Try it", sub: tried ? "\u{201C}\(viewModel.lastResult)\u{201D}" : (viewModel.holdKeyLabel != nil ? "Hold \(viewModel.holdKeyLabel!), say something, let go" : "Hold your shortcut, say something, let go"), done: tried) {
                    EmptyView()
                }
            }

            Spacer()

            HStack {
                if !allDone {
                    Button("Skip for now") { viewModel.setupCompleted = true }
                        .buttonStyle(.plain).font(.glass(11, .bold)).foregroundColor(theme.secondary)
                }
                Spacer()
                PillButton(title: allDone ? "Start speaking" : "Done", icon: "arrow.right", primary: true, theme: theme) {
                    viewModel.setupCompleted = true
                }
            }
        }
    }

    private var keySub: String {
        switch viewModel.apiKeyStatus {
        case .invalid: return "That key was rejected \u{2014} check it and save again"
        case .noCredits: return "Key OK, but the account has no credits"
        default: return "Paste your key and save"
        }
    }

    private func step<Action: View>(_ n: Int, _ title: String, sub: String, done: Bool, @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if done {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 26, height: 26).background(AppTheme.mint).clipShape(Circle())
            } else {
                Text("\(n)").font(.glass(11, .heavy)).foregroundColor(theme.secondary)
                    .frame(width: 26, height: 26).background(theme.segmentTrack).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.glass(12, .heavy)).foregroundColor(theme.ink).strikethrough(done, color: theme.ink.opacity(0.3))
                Text(sub).font(.glass(10, .semibold)).foregroundColor(theme.secondary).lineLimit(1).truncationMode(.tail)
                if !done && n == 1 { action() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !done && n != 1 { action() }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .glassCard(theme, radius: 16)
        .opacity(done ? 0.75 : 1)
    }
}
