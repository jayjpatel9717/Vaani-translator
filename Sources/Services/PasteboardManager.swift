import AppKit
import Foundation
import ApplicationServices

@MainActor
final class PasteboardManager {
    enum Outcome {
        case sent, copied, clipboardChanged
        var message: String {
            switch self {
            case .sent: return "Paste sent"
            case .copied: return "Copied — press ⌘V to paste"
            case .clipboardChanged: return "Clipboard changed — text is in Vaani history"
            }
        }
    }

    private static var deliveryGeneration = 0
    private static var activationObserver: NSObjectProtocol?
    private static var lastExternalApp: NSRunningApplication?

    static func hasAccessibilityPermission() -> Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Remember the user's editor even when opening Vaani's popover takes focus.
    static func startTrackingFocus() {
        guard activationObserver == nil else { return }
        remember(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in remember(app) }
        }
    }

    private static func remember(_ app: NSRunningApplication?) {
        if let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
           app.activationPolicy == .regular, !app.isTerminated {
            lastExternalApp = app
        }
    }

    static func captureTarget() -> NSRunningApplication? {
        deliveryGeneration += 1 // A new dictation cancels an older pending paste.
        remember(NSWorkspace.shared.frontmostApplication)
        guard let app = lastExternalApp, !app.isTerminated else { return nil }
        return app
    }

    /// Paste once through the app's normal keyboard path, never through AXSelectedText.
    /// Some browser/Electron fields accept an AX write without inserting the text.
    static func pasteText(_ text: String, recordedTarget: NSRunningApplication?,
                          completion: @escaping (Outcome) -> Void) {
        deliveryGeneration += 1
        let generation = deliveryGeneration
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(text, forType: .string) else { completion(.clipboardChanged); return }
        let clipboardVersion = board.changeCount
        let front = NSWorkspace.shared.frontmostApplication
        let recorded = recordedTarget?.isTerminated == false ? recordedTarget : nil
        let pid = PasteDeliveryPolicy.destination(frontmost: front?.processIdentifier,
            recorded: recorded?.processIdentifier, ownPID: ProcessInfo.processInfo.processIdentifier)
        guard let pid, let target = NSRunningApplication(processIdentifier: pid),
              AXIsProcessTrusted() else { completion(.copied); return }

        // Restore focus only if Vaani took it. If the user selected another app,
        // the destination is that app's current cursor, not an old text field.
        if front?.processIdentifier != pid {
            guard target.activate(options: []) else { completion(.copied); return }
        }
        attemptPaste(target: target, clipboardVersion: clipboardVersion, generation: generation, attemptsLeft: 30, completion: completion)
    }

    private static func attemptPaste(target: NSRunningApplication, clipboardVersion: Int,
                                     generation: Int, attemptsLeft: Int, completion: @escaping (Outcome) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard generation == deliveryGeneration else { return }
            let held: CGEventFlags = [.maskControl, .maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]
            let decision = PasteDeliveryPolicy.delivery(
                trusted: AXIsProcessTrusted(), targetAlive: !target.isTerminated,
                focused: NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
                modifiersHeld: !CGEventSource.flagsState(.combinedSessionState).intersection(held).isEmpty,
                clipboardUnchanged: NSPasteboard.general.changeCount == clipboardVersion,
                attemptsLeft: attemptsLeft)
            switch decision {
            case .wait:
                attemptPaste(target: target, clipboardVersion: clipboardVersion,
                             generation: generation, attemptsLeft: attemptsLeft - 1, completion: completion)
            case .copied: completion(.copied)
            case .clipboardChanged: completion(.clipboardChanged)
            case .send: sendPaste(to: target.processIdentifier, clipboardVersion: clipboardVersion, generation: generation, completion: completion)
            }
        }
    }

    private static func sendPaste(to pid: pid_t, clipboardVersion: Int, generation: Int, completion: @escaping (Outcome) -> Void) {
        // Private event state avoids inheriting the dictation trigger's Control flag.
        guard let source = CGEventSource(stateID: .privateState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            completion(.copied); return
        }
        commandDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        commandUp.flags = []
        commandDown.postToPid(pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard generation == deliveryGeneration,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  NSPasteboard.general.changeCount == clipboardVersion else {
                commandUp.postToPid(pid)
                completion(.copied)
                return
            }
            vDown.postToPid(pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                vUp.postToPid(pid)
                commandUp.postToPid(pid)
                // Posting events is not proof that every third-party editor accepted them.
                completion(.sent)
            }
        }
    }
}
