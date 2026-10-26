// Independent of event delivery so shortcut conflicts can be tested without recording.
struct ControlHoldGesture {
    enum Phase { case idle, waiting, recording, suppressed }
    enum Action: Equatable { case none, schedule, start, finish, cancel }
    private(set) var phase: Phase = .idle

    mutating func update(control: Bool, otherModifier: Bool, keyDown: Bool) -> Action {
        if !control {
            let wasRecording = phase == .recording
            phase = .idle
            return wasRecording ? .finish : .none
        }
        if otherModifier || keyDown {
            let wasRecording = phase == .recording
            phase = .suppressed
            return wasRecording ? .cancel : .none
        }
        if phase == .idle {
            phase = .waiting
            return .schedule
        }
        return .none
    }

    mutating func heldLongEnough() -> Action {
        guard phase == .waiting else { return .none }
        phase = .recording
        return .start
    }

    mutating func reset() -> Action {
        let wasRecording = phase == .recording
        phase = .idle
        return wasRecording ? .cancel : .none
    }
}
