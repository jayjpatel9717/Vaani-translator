import SwiftUI
import AppKit

enum HUDState: Equatable {
    case hidden
    case listening
    case translating(since: Date)
    case done(String)
    case error(String)
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var state: HUDState = .hidden
    @Published var level: Float = 0
}

/// Floating, click-through status pill near the bottom of the screen the mouse is on.
@MainActor
final class StatusHUD {
    private static let size = NSSize(width: 320, height: 64)
    private let panel: NSPanel
    private let model = HUDModel()
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
    }

    func update(level: Float) {
        model.level = level
    }

    func show(_ state: HUDState) {
        hideWork?.cancel()
        model.state = state
        switch state {
        case .hidden:
            hide()
            return
        case .done:
            scheduleHide(after: 1.5)
        case .error:
            scheduleHide(after: 4)
        default:
            break
        }
        if !panel.isVisible {
            place()
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleHide(after seconds: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func hide() {
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            if panel.alphaValue == 0 { panel.orderOut(nil) }
        })
    }

    private func place() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + 48)
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: false)
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel
    @State private var spin = false

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .font(.glass(13, .bold))
        .foregroundColor(Color(hex: 0x1E1B2E))
        .padding(.horizontal, 18)
        .frame(height: 46)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color.white.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.95)))
        .shadow(color: Color(hex: 0x1E1B2E).opacity(0.18), radius: 15, y: 8)
        .frame(width: 320, height: 64)
        .animation(.easeInOut(duration: 0.2), value: model.state)
        .onAppear { withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { spin = true } }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .hidden:
            EmptyView()
        case .listening:
            LevelBars(level: model.level)
            Text("Listening")
        case .translating(let since):
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(AngularGradient(colors: [AppTheme.violet, AppTheme.coral], center: .center), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(spin ? 360 : 0))
            TimelineView(.periodic(from: since, by: 0.1)) { ctx in
                Text("Translating \u{00B7} \(String(format: "%.1f", ctx.date.timeIntervalSince(since)))s")
                    .monospacedDigit()
            }
        case .done(let message):
            Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                .frame(width: 18, height: 18).background(AppTheme.mint).clipShape(Circle())
            Text(message)
        case .error(let message):
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Color(hex: 0xB8741A))
            Text(message).font(.glass(12, .bold)).lineLimit(2)
        }
    }
}

struct LevelBars: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [AppTheme.coral, AppTheme.violet], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 6 + CGFloat(min(1, max(0, level * 10 - Float(i) * 0.15))) * 14)
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.08), value: level)
    }
}
