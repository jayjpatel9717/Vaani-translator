func check(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }
let own: Int32 = 10
check(PasteDeliveryPolicy.destination(frontmost: 20, recorded: 30, ownPID: own) == 20, "use current cursor app")
check(PasteDeliveryPolicy.destination(frontmost: own, recorded: 30, ownPID: own) == 30, "restore app if Vaani took focus")
check(PasteDeliveryPolicy.destination(frontmost: own, recorded: nil, ownPID: own) == nil, "never paste into Vaani by accident")
check(PasteDeliveryPolicy.destination(frontmost: nil, recorded: 30, ownPID: own) == 30, "restore recorded target")
func decision(trusted: Bool = true, alive: Bool = true, focused: Bool = true, held: Bool = false, sameClipboard: Bool = true, left: Int = 3) -> PasteDeliveryPolicy.Decision {
    PasteDeliveryPolicy.delivery(trusted: trusted, targetAlive: alive, focused: focused, modifiersHeld: held, clipboardUnchanged: sameClipboard, attemptsLeft: left)
}
check(decision() == .send, "ready sends once")
check(decision(held: true) == .wait, "wait for Control release")
check(decision(focused: false) == .wait, "wait for activation")
check(decision(held: true, left: 0) == .copied, "bounded wait")
check(decision(focused: false, left: 0) == .copied, "never send to wrong app")
check(decision(sameClipboard: false) == .clipboardChanged, "do not paste unrelated clipboard content")
check(decision(trusted: false) == .copied, "permission loss reports copied")
check(decision(alive: false) == .copied, "closed target reports copied")
print("Paste delivery: target selection, focus, modifier release, clipboard changes and failure outcomes passed")
