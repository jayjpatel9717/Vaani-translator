import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @State private var pulseScale: CGFloat = 1.0
    @State private var showCopied = false

    // Brand gradient (blue → warm, matching icon)
    private let brandGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.45, blue: 0.95), Color(red: 0.85, green: 0.5, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let recordingGradient = LinearGradient(
        colors: [.red, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        if viewModel.showSettings {
            SettingsView()
                .environmentObject(viewModel)
        } else {
            mainContent
        }
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

    var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 1) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Vaani")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Translate & Transcribe")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Status line
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : (viewModel.hasAPIKey() ? Color.green : Color.orange))
                    .frame(width: 6, height: 6)

                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.mini)
                }

                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Accessibility warning
            if !viewModel.accessibilityGranted {
                Button(action: { PasteboardManager.requestAccessibilityPermission() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("Enable Accessibility for auto-paste")
                            .font(.system(size: 11))
                        Spacer()
                        Text("Fix")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            ScrollView {
                VStack(spacing: 20) {
                    // Mic hero
                    ZStack {
                        if viewModel.isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 80, height: 80)
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
                            .fill(viewModel.isRecording ? recordingGradient : brandGradient)
                            .frame(width: 64, height: 64)
                            .shadow(
                                color: viewModel.isRecording ? .red.opacity(0.25) : Color(red: 0.35, green: 0.45, blue: 0.95).opacity(0.2),
                                radius: 12
                            )

                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(viewModel.isRecording ? 1.0 + CGFloat(viewModel.audioLevel * 0.3) : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                    }
                    .padding(.top, 16)

                    // Controls row
                    VStack(spacing: 10) {
                        // Mode
                        HStack {
                            Text("Mode")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(.tertiaryLabelColor))
                            Spacer()
                            Picker("", selection: $viewModel.selectedMode) {
                                ForEach(TranslationMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }

                        // Target language (only for Translate mode)
                        if viewModel.selectedMode.needsTargetLanguage {
                            HStack {
                                Text("Language")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabelColor))
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
                    .padding(.horizontal, 20)

                    // Result
                    if !viewModel.lastResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Result")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabelColor))
                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(viewModel.lastResult, forType: .string)
                                    showCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
                                }) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(showCopied ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")

                                Button(action: {
                                    PasteboardManager.pasteText(viewModel.lastResult)
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Paste at cursor")
                            }

                            Text(viewModel.lastResult)
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Error
                    if let error = viewModel.lastError {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                                .font(.system(size: 11))
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
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }

                    // History
                    if !viewModel.history.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Recent")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(.tertiaryLabelColor))
                                Spacer()
                                Button(action: { viewModel.history.removeAll() }) {
                                    Text("Clear")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.history.prefix(3).enumerated()), id: \.element.id) { index, item in
                                    if index > 0 {
                                        Divider().padding(.leading, 12)
                                    }
                                    HStack(spacing: 6) {
                                        Text(item.text)
                                            .font(.system(size: 11))
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
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()

            // Bottom bar
            HStack {
                Text("Hold to speak. Instant translation.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabelColor))
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
        }
        .frame(width: 380, height: 500)
        .clipped()
    }
}
