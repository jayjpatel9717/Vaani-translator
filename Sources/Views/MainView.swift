import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    @State private var showCopied = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        Group {
            if viewModel.showSettings {
                SettingsView()
                    .environmentObject(viewModel)
            } else {
                mainContent
            }
        }
        .preferredColorScheme(viewModel.appearanceMode.preferredColorScheme)
        .animation(.easeInOut(duration: 0.25), value: colorScheme)
    }

    private var statusText: String {
        if viewModel.isRecording {
            return "Listening\u{2026}"
        } else if viewModel.isProcessing {
            return "Processing\u{2026}"
        } else if !viewModel.lastResult.isEmpty {
            return "Ready \u{00B7} \(String(format: "%.1fs", viewModel.processingTime))"
        } else {
            return viewModel.useFnKey ? "Hold fn to speak" : "Hold shortcut to speak"
        }
    }

    private var statusDotColor: Color {
        if viewModel.isRecording {
            return theme.statusError
        } else if viewModel.hasAPIKey() {
            return theme.statusSuccess
        } else {
            return theme.statusWarning
        }
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            // Header + Status (compact)
            HStack {
                Text("Vaani")
                    .font(.system(size: 15, weight: .semibold))

                Circle()
                    .fill(statusDotColor)
                    .frame(width: 7, height: 7)

                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.mini)
                }

                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { viewModel.showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 12)

            // Accessibility warning
            if !viewModel.accessibilityGranted {
                Button(action: {
                    // Open System Settings > Privacy > Accessibility directly
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.statusWarning)
                            .font(.system(size: 11))
                        Text("Grant Accessibility in System Settings")
                            .font(.system(size: 11))
                        Spacer()
                        Text("Open")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .padding(8)
                    .background(theme.warningTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.statusWarning.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 16) {
                    // Mic hero (compact)
                    ZStack {
                        if viewModel.isRecording {
                            Circle()
                                .stroke(theme.recordingPulse, lineWidth: 1.5)
                                .frame(width: 60, height: 60)
                                .scaleEffect(pulseScale)
                                .opacity(2 - pulseScale)
                                .onAppear {
                                    withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                        pulseScale = 2.0
                                    }
                                }
                                .onDisappear { pulseScale = 1.0 }
                        }

                        Circle()
                            .fill(viewModel.isRecording ? theme.recordingGradient : theme.brandGradient)
                            .frame(width: 48, height: 48)
                            .shadow(
                                color: viewModel.isRecording ? theme.recordingShadow : theme.brandShadow,
                                radius: theme.shadowRadius
                            )

                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(viewModel.isRecording ? 1.0 + CGFloat(viewModel.audioLevel * 0.3) : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                    }
                    .padding(.top, 12)

                    // Controls row
                    VStack(spacing: 8) {
                        HStack {
                            Text("Mode")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.sectionHeaderColor)
                            Spacer()
                            Picker("", selection: $viewModel.selectedMode) {
                                ForEach(TranslationMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }

                        if viewModel.selectedMode.needsTargetLanguage {
                            HStack {
                                Text("Language")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.sectionHeaderColor)
                                Spacer()
                                Picker("", selection: $viewModel.targetLanguage) {
                                    ForEach(Language.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Result
                    if !viewModel.lastResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Result")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.sectionHeaderColor)
                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(viewModel.lastResult, forType: .string)
                                    showCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
                                }) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(showCopied ? theme.statusSuccess : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")

                                Button(action: {
                                    PasteboardManager.pasteText(viewModel.lastResult)
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Paste at cursor")
                            }

                            Text(viewModel.lastResult)
                                .font(.system(size: 16))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    // Error
                    if let error = viewModel.lastError {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(theme.statusError)
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { viewModel.lastError = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.errorTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.statusError.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }

                    // History
                    if !viewModel.history.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Recent")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.sectionHeaderColor)
                                Spacer()
                                Button(action: { viewModel.history.removeAll() }) {
                                    Text("Clear")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.history.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 {
                                        Divider().padding(.leading, 12)
                                    }
                                    HStack(spacing: 6) {
                                        Text(item.text)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(item.text, forType: .string)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                }
                            }
                            .background(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .frame(width: 340, height: 400)
        .clipped()
    }
}
