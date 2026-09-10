import AppKit
import KeyboardShortcuts

// Same call path that crashed Vaani: RecorderCocoa.init -> "...".localized -> resource bundle lookup.
extension KeyboardShortcuts.Name {
    static let check = Self("bundle-check")
}

_ = KeyboardShortcuts.RecorderCocoa(for: .check)
print("OK: recorder created from \(Bundle.main.bundleURL.path)")
