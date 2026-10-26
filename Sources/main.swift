import SwiftUI
import KeyboardShortcuts
import AppKit
import Combine

extension KeyboardShortcuts.Name {
    static let record = Self("record", default: .init(.space, modifiers: .control))
}

// Developer hook: VAANI_SNAPSHOT_DIR=/some/dir renders every screen to PNG and exits.
// Used to eyeball the UI without driving the menu bar: see Tests/snapshots.sh
@MainActor
func renderSnapshots(to dir: String) {
    let vm = TranslatorViewModel()
    vm.setupCompleted = true
    vm.apiKeyStatus = .ok
    vm.micGranted = true
    vm.accessibilityGranted = true
    vm.history = [
        HistoryItem(text: "नमस्ते, कैसे हैं आप?", toLang: .hindi, mode: .translit, date: Date()),
        HistoryItem(text: "kal subah nau baje milte hain", toLang: .hindi, mode: .codemix, date: Date()),
        HistoryItem(text: "Meeting moved to Thursday", toLang: .english, mode: .translate, date: Date()),
    ]
    let states: [(String, () -> Void)] = [
        ("1-ready", {}),
        ("2-listening", { vm.isRecording = true; vm.audioLevel = 0.06 }),
        ("3-translating", { vm.isRecording = false; vm.isProcessing = true; vm.hudState = .translating(since: Date()) }),
        ("4-nocredits", { vm.isProcessing = false; vm.hudState = .hidden; vm.apiKeyStatus = .noCredits }),
        ("5-settings", { vm.apiKeyStatus = .ok; vm.showSettings = true }),
        ("6-setup", { vm.showSettings = false; vm.setupCompleted = false; vm.accessibilityGranted = false }),
    ]
    for (name, apply) in states {
        apply()
        let renderer = ImageRenderer(content: MainView().environmentObject(vm))
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            do {
                try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                print("wrote \(name).png \(image.size)")
            } catch {
                print("write failed \(name): \(error)")
            }
        } else {
            print("render failed \(name): image=\(renderer.nsImage == nil ? "nil" : "ok")")
        }
    }
    let hud = HUDModel()
    hud.state = .done("Pasted")
    let hudRenderer = ImageRenderer(content: HUDView(model: hud).frame(width: 340, height: 64).background(Color(hex: 0xE9E1DA)))
    hudRenderer.scale = 2
    if let image = hudRenderer.nsImage, let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("7-pill.png"))
    }
}

if let dir = ProcessInfo.processInfo.environment["VAANI_SNAPSHOT_DIR"] {
    MainActor.assumeIsolated { renderSnapshots(to: dir) }
    exit(0)
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
    var controlKeyMonitor: ControlKeyMonitor?
    var controlOwnsRecording = false
    var hud: StatusHUD?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        PasteboardManager.startTrackingFocus()
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
        popover.contentSize = NSSize(width: 340, height: 440)
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

        controlKeyMonitor = ControlKeyMonitor()
        controlKeyMonitor?.onDown = { [weak self] in
            Task { @MainActor in
                guard let self, !self.viewModel.isRecording, !self.viewModel.isProcessing,
                      !(self.popover?.isShown == true && self.viewModel.showSettings) else { return }
                self.controlOwnsRecording = true
                self.popover?.performClose(nil)
                self.viewModel.startRecording()
                self.updateStatusIcon(recording: true)
            }
        }
        controlKeyMonitor?.onUp = { [weak self] in
            Task { @MainActor in
                guard let self, self.controlOwnsRecording else { return }
                self.controlOwnsRecording = false
                self.viewModel.stopRecording()
                self.updateStatusIcon(recording: false)
            }
        }
        controlKeyMonitor?.onCancel = { [weak self] in
            Task { @MainActor in
                guard let self, self.controlOwnsRecording else { return }
                self.controlOwnsRecording = false
                self.viewModel.cancelRecording()
                self.updateStatusIcon(recording: false)
            }
        }
        viewModel.$useControlKey
            .sink { [weak self] enabled in
                if enabled { self?.controlKeyMonitor?.start() }
                else { self?.controlKeyMonitor?.stop() }
            }
            .store(in: &cancellables)

        // Floating status pill (Listening / Translating / Pasted / error)
        let hud = StatusHUD()
        self.hud = hud
        viewModel.$hudState
            .receive(on: DispatchQueue.main)
            .sink { hud.show($0) }
            .store(in: &cancellables)
        viewModel.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { hud.update(level: $0) }
            .store(in: &cancellables)

        // Mark the icon on any failure; open the popover only when the user must act in Settings
        viewModel.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.statusItem?.button?.contentTintColor = .systemOrange
                if !self.viewModel.apiKeyValid { self.showPopover() }
            }
            .store(in: &cancellables)

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

        // First run: show the setup checklist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.viewModel.loadKeychainIfNeeded()
            if !self.viewModel.setupCompleted {
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

        menu.addItem(withTitle: "Vaani v1.1.0", action: nil, keyEquivalent: "")
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
