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

    /// Copies text to clipboard AND inserts at cursor position
    static func pasteText(_ text: String) {
        // Always copy to clipboard so user can also manually Cmd+V
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Strategy 1: Direct text insertion via Accessibility API
            if insertTextAtCursor(text) { return }

            // Strategy 2: Trigger Paste menu item via Accessibility API
            if performPasteViaMenu() { return }

            // Strategy 3: CGEvent Cmd+V simulation (last resort)
            simulateCmdV()
        }
    }

    // MARK: - Strategy 1: Direct text insertion

    /// Inserts text at cursor by setting AXSelectedText on the focused element
    private static func insertTextAtCursor(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success, let element = focusedElement else {
            return false
        }

        let axElement = element as! AXUIElement
        let setResult = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return setResult == .success
    }

    // MARK: - Strategy 2: Menu-based paste

    /// Finds and clicks the Paste menu item (Cmd+V) in the frontmost app
    private static func performPasteViaMenu() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBar
        ) == .success else { return false }

        // Get top-level menus
        var menus: AnyObject?
        guard AXUIElementCopyAttributeValue(
            menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menus
        ) == .success, let menuArray = menus as? [AXUIElement] else { return false }

        // Search each menu for Paste item (identified by Cmd+V shortcut)
        for menu in menuArray {
            var submenuList: AnyObject?
            AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuList)
            guard let submenus = submenuList as? [AXUIElement] else { continue }

            for submenu in submenus {
                var items: AnyObject?
                AXUIElementCopyAttributeValue(submenu, kAXChildrenAttribute as CFString, &items)
                guard let itemArray = items as? [AXUIElement] else { continue }

                for item in itemArray {
                    // Match by keyboard shortcut character "v" (locale-independent)
                    var cmdChar: AnyObject?
                    AXUIElementCopyAttributeValue(
                        item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar
                    )

                    if let charStr = cmdChar as? String, charStr.lowercased() == "v" {
                        // Verify it's plain Cmd+V (no extra modifiers like Shift/Option)
                        var modifiers: AnyObject?
                        AXUIElementCopyAttributeValue(
                            item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiers
                        )
                        let mod = modifiers as? Int ?? 0
                        if mod == 0 { // 0 = only Command key
                            return AXUIElementPerformAction(
                                item, kAXPressAction as CFString
                            ) == .success
                        }
                    }
                }
            }
        }

        return false
    }

    // MARK: - Strategy 3: CGEvent Cmd+V

    /// Simulates Cmd+V via CGEvent as last resort
    private static func simulateCmdV() {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
                  let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
                return
            }

            vDown.flags = .maskCommand
            vUp.flags = .maskCommand

            vDown.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
            vUp.post(tap: .cghidEventTap)
        }
    }
}
