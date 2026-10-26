/// Pure decision logic; no clipboard, accessibility or keyboard access.
enum PasteDeliveryPolicy {
    enum Decision: Equatable { case wait, send, copied, clipboardChanged }

    static func destination(frontmost: Int32?, recorded: Int32?, ownPID: Int32) -> Int32? {
        if let frontmost, frontmost != ownPID { return frontmost }
        if let recorded, recorded != ownPID { return recorded }
        return nil
    }

    static func delivery(trusted: Bool, targetAlive: Bool, focused: Bool,
                         modifiersHeld: Bool, clipboardUnchanged: Bool,
                         attemptsLeft: Int) -> Decision {
        guard clipboardUnchanged else { return .clipboardChanged }
        guard trusted, targetAlive else { return .copied }
        guard focused, !modifiersHeld else { return attemptsLeft > 0 ? .wait : .copied }
        return .send
    }
}
