import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResult = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    private enum Phase { case ready, listening, translating, result, noCredits, error(String) }

    private var phase: Phase {
        if viewModel.isRecording { return .listening }
        if viewModel.isProcessing { return .translating }
        if viewModel.apiKeyStatus == .noCredits { return .noCredits }
        if let error = viewModel.lastError { return .error(error) }
        if showResult, !viewModel.lastResult.isEmpty { return .result }
        return .ready
    }

    var body: some View {
        ZStack {
            MeshBackground(theme: theme)
            Group {
                if !viewModel.setupCompleted {
                    SetupView().environmentObject(viewModel)
                } else if viewModel.showSettings {
                    SettingsView().environmentObject(viewModel)
                } else {
                    mainContent
                }
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 18, trailing: 20))
        }
        .frame(width: 340, height: 440)
        .preferredColorScheme(viewModel.appearanceMode.preferredColorScheme)
        .onChange(of: viewModel.isProcessing) { processing in
            if !processing && !viewModel.lastResult.isEmpty && viewModel.lastError == nil { showResult = true }
        }
        .onChange(of: viewModel.isRecording) { recording in
            if recording { showResult = false }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .ready: readyBody
            case .listening: listeningBody
            case .translating: translatingBody
            case .result: resultBody
            case .noCredits: noCreditsBody
            case .error(let message): errorBody(message)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isProcessing)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Vaani").font(.glass(20, .heavy)).foregroundColor(theme.ink)
                subtitle
            }
            Spacer()
            switch phase {
            case .listening:
                timerChip
            case .result:
                IconCircleButton(systemName: "checkmark", theme: theme, tint: AppTheme.mint) { showResult = false }
            default:
                IconCircleButton(systemName: "gearshape.fill", theme: theme) { viewModel.showSettings = true }
            }
        }
    }

    @ViewBuilder private var subtitle: some View {
        switch phase {
        case .ready:
            Text("Ready to listen").font(.glass(11, .semibold)).foregroundColor(theme.secondary)
        case .listening:
            Text("Listening\u{2026}").font(.glass(11, .semibold)).foregroundColor(AppTheme.coral)
        case .translating:
            if case .translating(let since) = viewModel.hudState {
                TimelineView(.periodic(from: since, by: 0.1)) { ctx in
                    Text("Translating \u{00B7} \(ctx.date.timeIntervalSince(since), specifier: "%.1f")s")
                        .font(.glass(11, .semibold)).foregroundColor(AppTheme.violet).monospacedDigit()
                }
            } else {
                Text("Translating\u{2026}").font(.glass(11, .semibold)).foregroundColor(AppTheme.violet)
            }
        case .result:
            let message: String = { if case .done(let m) = viewModel.hudState { return m } else { return "Done" } }()
            Text(message).font(.glass(11, .semibold)).foregroundColor(theme.successText)
        case .noCredits:
            Text("Needs attention").font(.glass(11, .semibold)).foregroundColor(theme.warningText)
        case .error:
            Text("Something went wrong").font(.glass(11, .semibold)).foregroundColor(theme.warningText)
        }
    }

    private var timerChip: some View {
        HStack(spacing: 6) {
            Circle().fill(AppTheme.coral).frame(width: 7, height: 7)
            if let start = viewModel.recordingStartTime {
                TimelineView(.periodic(from: start, by: 1)) { ctx in
                    let s = Int(ctx.date.timeIntervalSince(start))
                    Text(String(format: "%d:%02d", s / 60, s % 60)).monospacedDigit()
                }
            }
        }
        .font(.glass(11, .heavy))
        .foregroundColor(theme.isDark ? AppTheme.coral : Color(hex: 0xC2481F))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(AppTheme.coral.opacity(0.18))
        .overlay(Capsule().stroke(AppTheme.coral.opacity(0.45), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var holdHint: some View {
        HStack(spacing: 5) {
            Text("Hold")
            if let label = viewModel.holdKeyLabel { Keycap(text: label, theme: theme) } else { Text("your shortcut") }
            Text("and speak")
        }
        .font(.glass(11, .bold))
        .foregroundColor(theme.secondary)
        .frame(height: 18)
    }

    // MARK: Ready

    private var readyBody: some View {
        VStack(spacing: 0) {
            Orb(theme: theme, mode: .ready)
            holdHint
            Spacer().frame(height: 14)
            GlassSegmented(items: TranslationMode.allCases.map { ($0, $0.shortName) }, selection: $viewModel.selectedMode, theme: theme)
            Spacer().frame(height: 10)
            languageRow
            Spacer().frame(height: 14)
            recentList(dimmed: false)
        }
    }

    @ViewBuilder private var languageRow: some View {
        HStack {
            Text(viewModel.selectedMode.needsTargetLanguage ? "Output language" : "Source language")
                .font(.glass(11, .semibold)).foregroundColor(theme.secondary)
            Spacer()
            if viewModel.selectedMode.needsTargetLanguage {
                Menu {
                    ForEach(Language.allCases) { lang in
                        Button(lang.displayName) { viewModel.targetLanguage = lang }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.targetLanguage.displayName)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundColor(AppTheme.violet)
                    }
                    .font(.glass(11, .bold)).foregroundColor(theme.ink)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(theme.glass)
                    .overlay(Capsule().stroke(theme.glassBorder, lineWidth: 1))
                    .clipShape(Capsule())
                    .shadow(color: theme.shadow, radius: 4, y: 2)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            } else {
                Text("Detected automatically").font(.glass(11, .bold)).foregroundColor(theme.ink)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
    }

    // MARK: Listening

    private var listeningBody: some View {
        VStack(spacing: 0) {
            Orb(theme: theme, mode: .listening, icon: "waveform")
            WaveformBars(level: viewModel.audioLevel)
            Spacer().frame(height: 6)
            HStack(spacing: 5) {
                Text("Release")
                if let label = viewModel.holdKeyLabel { Keycap(text: label, theme: theme) } else { Text("the shortcut") }
                Text("when you\u{2019}re done")
            }
            .font(.glass(11, .bold)).foregroundColor(theme.secondary).frame(height: 18)
            Spacer().frame(height: 16)
            HStack(spacing: 8) {
                PillButton(title: viewModel.selectedMode.displayName, theme: theme) {}
                if viewModel.selectedMode.needsTargetLanguage {
                    PillButton(title: viewModel.targetLanguage.displayName, theme: theme) {}
                }
            }
            Spacer()
            recentList(dimmed: true, limit: 1)
        }
    }

    // MARK: Translating

    private var translatingBody: some View {
        VStack(spacing: 0) {
            Orb(theme: theme, mode: .translating, icon: "sparkles")
            Text(viewModel.selectedMode.needsTargetLanguage
                 ? "Speech \u{2192} \(viewModel.targetLanguage.displayName)"
                 : "Speech \u{2192} \(viewModel.selectedMode.displayName)")
                .font(.glass(11, .bold)).foregroundColor(theme.secondary).frame(height: 18)
            Spacer().frame(height: 18)
            VStack(alignment: .leading, spacing: 10) {
                ForEach([0.88, 0.64, 0.40], id: \.self) { w in
                    Capsule().fill(theme.ink.opacity(0.12)).frame(width: 272 * w, height: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassCard(theme, radius: 16)
            Spacer()
            Text(viewModel.accessibilityGranted ? "Result will be pasted where your cursor is" : "Result will be copied to your clipboard")
                .font(.glass(11, .semibold)).foregroundColor(theme.secondary)
        }
    }

    // MARK: Result

    private var resultBody: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.lastResult)
                    .font(.glass(17, .bold)).foregroundColor(theme.ink)
                    .lineLimit(4).lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Text("\(viewModel.selectedMode.displayName) \u{00B7} \(viewModel.processingTime, specifier: "%.1f")s")
                        .font(.glass(10, .bold)).foregroundColor(theme.secondary)
                    Spacer()
                    IconCircleButton(systemName: "doc.on.doc", theme: theme) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.lastResult, forType: .string)
                    }
                }
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
            .glassCard(theme, radius: 18)
            Spacer().frame(height: 16)
            HStack(spacing: 5) {
                Text("Hold")
                if let label = viewModel.holdKeyLabel { Keycap(text: label, theme: theme) } else { Text("your shortcut") }
                Text("to speak again")
            }
            .font(.glass(11, .bold)).foregroundColor(theme.secondary).frame(height: 18)
            Spacer()
            recentList(dimmed: false, title: "EARLIER", skipFirst: true, limit: 2)
        }
    }

    // MARK: Errors

    private var noCreditsBody: some View {
        VStack(spacing: 0) {
            Orb(theme: theme, mode: .off, size: 72)
            attentionCard(
                title: "Your Sarvam account is out of credits",
                body: "Your key is valid. Top up and Vaani keeps working, nothing to reconfigure."
            ) {
                PillButton(title: "Add credits", icon: "arrow.right", primary: true, theme: theme) {
                    NSWorkspace.shared.open(URL(string: "https://dashboard.sarvam.ai")!)
                }
                PillButton(title: "Check again", theme: theme) { viewModel.validateAPIKey() }
            }
            Spacer()
            recentList(dimmed: true, limit: 1)
        }
    }

    private func errorBody(_ message: String) -> some View {
        VStack(spacing: 0) {
            Orb(theme: theme, mode: .off, size: 72)
            attentionCard(title: message, body: nil) {
                if !viewModel.apiKeyValid {
                    PillButton(title: "Open Settings", primary: true, theme: theme) { viewModel.showSettings = true }
                }
                PillButton(title: "Dismiss", theme: theme) { viewModel.lastError = nil }
            }
            Spacer()
            recentList(dimmed: true, limit: 1)
        }
    }

    private func attentionCard<Actions: View>(title: String, body: String?, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(theme.warningText).padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.glass(13, .heavy)).foregroundColor(theme.ink).fixedSize(horizontal: false, vertical: true)
                    if let body {
                        Text(body).font(.glass(11, .semibold)).foregroundColor(theme.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: 8) { actions() }.padding(.leading, 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.amber.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.amber.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: theme.shadow, radius: 9, y: 6)
    }

    // MARK: Recent

    @ViewBuilder
    private func recentList(dimmed: Bool, title: String? = nil, skipFirst: Bool = false, limit: Int = 3) -> some View {
        let items = Array(viewModel.history.dropFirst(skipFirst ? 1 : 0).prefix(limit))
        if !items.isEmpty {
            VStack(spacing: 6) {
                if let title {
                    HStack {
                        Text(title).font(.glass(10, .heavy)).foregroundColor(theme.tertiary).tracking(1)
                        Spacer()
                        Button("Clear") { viewModel.history.removeAll() }
                            .buttonStyle(.plain).font(.glass(10, .bold)).foregroundColor(theme.secondary)
                    }
                    .padding(.bottom, 2)
                }
                ForEach(items) { item in
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.text, forType: .string)
                    }) {
                        HStack(spacing: 10) {
                            Circle().fill(AppTheme.modeColor(item.mode)).frame(width: 8, height: 8)
                            Text(item.text).font(.glass(12, .semibold)).foregroundColor(theme.ink).lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 6)
                            Text(item.mode.shortName).font(.glass(10, .bold)).foregroundColor(theme.secondary)
                        }
                        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassCard(theme, radius: 14, dimmed: dimmed)
                    .help("Copy")
                }
            }
        }
    }
}
