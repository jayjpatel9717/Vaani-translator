import SwiftUI
import KeyboardShortcuts
import AppKit
import Combine

extension KeyboardShortcuts.Name {
    static let record = Self("record", default: .init(.space, modifiers: .control))
}

// Prevent multiple instances
let runningApps = NSWorkspace.shared.runningApplications.filter {
    $0.bundleIdentifier == Bundle.main.bundleIdentifier
}
if runningApps.count > 1 {
    if let existing = runningApps.first(where: { $0 != NSRunningApplication.current }) {
        existing.activate()
    }
    exit(0)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var viewModel: TranslatorViewModel!
    var eventMonitor: Any?
    var fnKeyMonitor: FnKeyMonitor?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            self.viewModel = TranslatorViewModel()
            self.setupUI()
        }
    }

    @MainActor
    func setupUI() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Vaani")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Register keyboard shortcut
        KeyboardShortcuts.onKeyDown(for: .record) { [weak self] in
            Task { @MainActor in
                // Close popover so it doesn't interfere with focus
                if let popover = self?.popover, popover.isShown {
                    popover.performClose(nil)
                }
                self?.viewModel.startRecording()
                self?.updateStatusIcon(recording: true)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .record) { [weak self] in
            Task { @MainActor in
                self?.viewModel.stopRecording()
                self?.updateStatusIcon(recording: false)
            }
        }

        // Setup popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MainView().environmentObject(viewModel)
        )
        self.popover = popover

        // Close popover on any click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        // Request Accessibility permission for auto-paste (shows macOS prompt)
        if !PasteboardManager.hasAccessibilityPermission() {
            PasteboardManager.requestAccessibilityPermission()
        }

        // Fn key monitor
        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor?.onFnDown = { [weak self] in
            Task { @MainActor in
                if let popover = self?.popover, popover.isShown {
                    popover.performClose(nil)
                }
                self?.viewModel.startRecording()
                self?.updateStatusIcon(recording: true)
            }
        }
        fnKeyMonitor?.onFnUp = { [weak self] in
            Task { @MainActor in
                self?.viewModel.stopRecording()
                self?.updateStatusIcon(recording: false)
            }
        }

        // Start/stop fn monitor based on setting
        viewModel.$useFnKey
            .sink { [weak self] useFn in
                if useFn {
                    self?.fnKeyMonitor?.start()
                } else {
                    self?.fnKeyMonitor?.stop()
                }
            }
            .store(in: &cancellables)

        // Show first-time setup if no API key
        if !viewModel.hasAPIKey() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.viewModel.showSettings = true
                self.showPopover()
            }
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show context menu
            showContextMenu()
        } else {
            // Left-click: toggle popover
            togglePopover()
        }
    }

    func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Vaani v1.0.0", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Vaani", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Reset menu so left-click works again for popover
        statusItem?.menu = nil
    }

    @objc func openSettings() {
        Task { @MainActor in
            self.viewModel.showSettings = true
            self.showPopover()
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func updateStatusIcon(recording: Bool) {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: recording ? "mic.circle.fill" : "mic.fill",
                accessibilityDescription: "Vaani"
            )
            if recording {
                button.contentTintColor = .red
            } else {
                button.contentTintColor = nil
            }
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        if let popover = popover, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Self.activateApp()
        }
    }

    static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                Self.activateApp()
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
