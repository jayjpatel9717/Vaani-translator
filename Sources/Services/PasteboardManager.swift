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

        guard AXIsProcessTrusted() else {
            log("SKIP: no accessibility permission")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let app = NSWorkspace.shared.frontmostApplication
            log("Frontmost: \(app?.localizedName ?? "nil") pid=\(app?.processIdentifier ?? 0)")

            // Strategy 1: Direct text insertion via AXSelectedText
            let s1 = insertTextAtCursor(text)
            log("Strategy 1 (AXSelectedText): \(s1 ? "OK" : "FAIL")")
            if s1 { return }

            // Strategy 2: Trigger Paste menu item via Accessibility API
            let s2 = performPasteViaMenu()
            log("Strategy 2 (Menu Paste): \(s2 ? "OK" : "FAIL")")
            if s2 { return }

            // Strategy 3: CGEvent Cmd+V (session level, bypasses HID taps)
            log("Strategy 3 (CGEvent cgSessionEventTap)")
            simulateCmdV()
        }
    }

    // MARK: - Strategy 1: Direct text insertion

    private static func insertTextAtCursor(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let copyResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard copyResult == .success, let element = focusedElement else {
            log("  AX focused element: not found (\(copyResult.rawValue))")
            return false
        }

        // Check if element supports AXSelectedText (is it writable?)
        var writable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &writable)
        guard writable.boolValue else {
            log("  AXSelectedText: not writable")
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

    private static func performPasteViaMenu() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBar
        ) == .success else {
            log("  No menu bar")
            return false
        }

        var menus: AnyObject?
        guard AXUIElementCopyAttributeValue(
            menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menus
        ) == .success, let menuArray = menus as? [AXUIElement] else { return false }

        for menu in menuArray {
            var submenuList: AnyObject?
            AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuList)
            guard let submenus = submenuList as? [AXUIElement] else { continue }

            for submenu in submenus {
                var items: AnyObject?
                AXUIElementCopyAttributeValue(submenu, kAXChildrenAttribute as CFString, &items)
                guard let itemArray = items as? [AXUIElement] else { continue }

                for item in itemArray {
                    var cmdChar: AnyObject?
                    AXUIElementCopyAttributeValue(
                        item, kAXMenuItemCmdCharAttribute as CFString, &cmdChar
                    )

                    if let charStr = cmdChar as? String, charStr.lowercased() == "v" {
                        var modifiers: AnyObject?
                        AXUIElementCopyAttributeValue(
                            item, kAXMenuItemCmdModifiersAttribute as CFString, &modifiers
                        )
                        let mod = modifiers as? Int ?? 0
                        if mod == 0 {
                            let r = AXUIElementPerformAction(item, kAXPressAction as CFString)
                            log("  Paste menu: action result \(r == .success ? "OK" : "FAIL(\(r.rawValue))")")
                            return r == .success
                        }
                    }
                }
            }
        }

        log("  Paste menu item not found")
        return false
    }

    // MARK: - Strategy 3: CGEvent Cmd+V

    private static func simulateCmdV() {
        // Post to cgSessionEventTap (bypasses our HID-level fn key monitor tap)
        guard let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            return
        }

        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        vDown.post(tap: .cgSessionEventTap)
        vUp.post(tap: .cgSessionEventTap)
    }

    // MARK: - Logging (debug builds only)

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[Vaani Paste] %@", message)
        #endif
    }
}
