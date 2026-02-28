import Foundation
import CoreGraphics
import AppKit

class FnKeyMonitor {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var nsEventMonitor: Any?
    private var retryTimer: Timer?
    private var _isFnDown = false
    private let fnStateLock = NSLock()

    fileprivate var isFnDown: Bool {
        get {
            fnStateLock.lock()
            defer { fnStateLock.unlock() }
            return _isFnDown
        }
        set {
            fnStateLock.lock()
            defer { fnStateLock.unlock() }
            _isFnDown = newValue
        }
    }

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    fileprivate static var active: FnKeyMonitor?

    func start() {
        guard eventTap == nil && nsEventMonitor == nil else { return }
        FnKeyMonitor.active = self
        isFnDown = false

        if !AXIsProcessTrusted() {
            startRetryTimer()
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyTapCallback,
            userInfo: nil
        ) {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }

            CGEvent.tapEnable(tap: tap, enable: true)
            stopRetryTimer()
        } else if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyTapCallback,
            userInfo: nil
        ) {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }

            CGEvent.tapEnable(tap: tap, enable: true)
            stopRetryTimer()
        } else {
            startNSEventMonitor()
        }
    }

    private func startNSEventMonitor() {
        nsEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let fnDown = event.modifierFlags.contains(.function)

            if fnDown && !self.isFnDown {
                self.isFnDown = true
                self.onFnDown?()
            } else if !fnDown && self.isFnDown {
                self.isFnDown = false
                self.onFnUp?()
            }
        }

        if nsEventMonitor != nil {
            stopRetryTimer()
        }
    }

    private func startRetryTimer() {
        stopRetryTimer()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                self.stopRetryTimer()
                self.eventTap = nil
                self.nsEventMonitor = nil
                self.start()
            }
        }
    }

    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let monitor = nsEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        stopRetryTimer()
        eventTap = nil
        runLoopSource = nil
        nsEventMonitor = nil
        isFnDown = false
        if FnKeyMonitor.active === self {
            FnKeyMonitor.active = nil
        }
    }

    deinit {
        stop()
    }
}

private func fnKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let monitor = FnKeyMonitor.active else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .flagsChanged else {
        return Unmanaged.passUnretained(event)
    }

    let fnDown = event.flags.contains(.maskSecondaryFn)

    if fnDown && !monitor.isFnDown {
        monitor.isFnDown = true
        DispatchQueue.main.async { monitor.onFnDown?() }
        return nil
    } else if !fnDown && monitor.isFnDown {
        monitor.isFnDown = false
        DispatchQueue.main.async { monitor.onFnUp?() }
        return nil
    }

    return Unmanaged.passUnretained(event)
}
