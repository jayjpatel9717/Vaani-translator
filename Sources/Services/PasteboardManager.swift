import AppKit
import Foundation
import ApplicationServices

class PasteboardManager {

    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Copies text to clipboard and simulates Cmd+V to paste at cursor
    static func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else { return }

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) {
            let source = CGEventSource(stateID: .combinedSessionState)
            source?.setLocalEventsFilterDuringSuppressionState(
                .permitLocalMouseEvents,
                state: .eventSuppressionStateSuppressionInterval
            )

            guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                  let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
                return
            }

            vDown.flags = .maskCommand
            vUp.flags = .maskCommand

            vDown.post(tap: .cghidEventTap)
            vUp.post(tap: .cghidEventTap)
        }
    }
}
