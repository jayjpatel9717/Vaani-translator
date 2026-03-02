import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseScale: CGFloat = 1.0

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
        } else if viewModel.lastError != nil {
            return "Error"
        } else if !viewModel.apiKeyValid {
            return "API key issue"
        } else if !viewModel.lastResult.isEmpty {
            return "Ready \u{00B7} \(String(format: "%.1fs", viewModel.processingTime))"
        } else {
            return viewModel.useFnKey ? "Hold fn to speak" : "Hold shortcut to speak"
        }
    }

    private var statusDotColor: Color {
        if viewModel.isRecording {
            return theme.statusError
        } else if viewModel.lastError != nil {
            return theme.statusError
        } else if viewModel.isProcessing {
            return theme.statusWarning
        } else if !viewModel.apiKeyValid {
            return theme.statusWarning
        } else if viewModel.hasAPIKey() {
            return theme.statusSuccess
        } else {
            return theme.statusWarning
        }
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            // Header
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

            // Main scrollable content
            ScrollView {
                VStack(spacing: 12) {
                    // Mic hero
                    ZStack {
                        if viewModel.isRecording {
                            Circle()
                                .stroke(theme.recordingPulse, lineWidth: 1.5)
                                .frame(width: 56, height: 56)
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
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: viewModel.isRecording ? theme.recordingShadow : theme.brandShadow,
                                radius: theme.shadowRadius
                            )

                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(viewModel.isRecording ? 1.0 + CGFloat(viewModel.audioLevel * 0.3) : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                    }
                    .padding(.top, 8)

                    // Controls
                    VStack(spacing: 6) {
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

                    // Recent results
                    if !viewModel.history.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
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
                            .padding(.bottom, 6)

                            VStack(spacing: 0) {
                                ForEach(viewModel.history) { (item: HistoryItem) in
                                    VStack(spacing: 0) {
                                        HStack(spacing: 8) {
                                            Text(item.text)
                                                .font(.system(size: 12))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Text(item.mode.shortName)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(theme.brandBlue)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(theme.brandBlue.opacity(0.12))
                                                .cornerRadius(3)

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
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)

                                        if item.id != viewModel.history.last?.id {
                                            Divider()
                                                .padding(.leading, 10)
                                        }
                                    }
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

                    // Error
                    if let error = viewModel.lastError {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(theme.statusError)
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { viewModel.lastError = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.errorTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.statusError.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
            }

            // Bottom bar: appearance toggle
            Divider()
                .padding(.horizontal, 12)
            HStack(spacing: 0) {
                Spacer()
                ForEach(AppearanceMode.allCases) { mode in
                    Button(action: { viewModel.appearanceMode = mode }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10))
                            .foregroundColor(viewModel.appearanceMode == mode ? theme.brandBlue : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .frame(width: 320, height: 380)
        .clipped()
    }
}
