import AppKit
import CoreGraphics

/// Observe Control without consuming it: existing Control shortcuts keep working.
final class ControlKeyMonitor {
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    var onCancel: (() -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?
    private var holdTimer: Timer?
    private var gesture = ControlHoldGesture()
    private var pressedKeys = Set<Int64>()

    func start() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { retry(); return }
        let mask = [CGEventType.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<ControlKeyMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.receive(type: type, event: event)
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { retry(); return }
        retryTimer?.invalidate()
        retryTimer = nil
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func retry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.start() }
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            perform(gesture.reset())
            holdTimer?.invalidate()
            pressedKeys.removeAll()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown { pressedKeys.insert(key) }
        if type == .keyUp { pressedKeys.remove(key) }
        let flags = event.flags
        let others: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskSecondaryFn]
        let action = gesture.update(control: flags.contains(.maskControl),
            otherModifier: !flags.intersection(others).isEmpty,
            keyDown: !pressedKeys.isEmpty || type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown)
        if gesture.phase != .waiting { holdTimer?.invalidate(); holdTimer = nil }
        perform(action)
    }

    private func perform(_ action: ControlHoldGesture.Action) {
        switch action {
        case .none: break
        case .schedule:
            holdTimer?.invalidate()
            let timer = Timer(timeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.perform(self.gesture.heldLongEnough())
            }
            holdTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        case .start: onDown?()
        case .finish: onUp?()
        case .cancel: onCancel?()
        }
    }

    func stop() {
        holdTimer?.invalidate(); holdTimer = nil
        retryTimer?.invalidate(); retryTimer = nil
        perform(gesture.reset())
        pressedKeys.removeAll()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    deinit { stop() }
}
