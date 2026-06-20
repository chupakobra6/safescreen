import OverlayBrowserCore
import Testing

@Suite("ModifierHotKeyPolicy")
struct ModifierHotKeyPolicyTests {
    @Test
    func recognizesLeftOptionShiftOnly() {
        #expect(activeSide([.leftOption, .leftShift]) == .left)
    }

    @Test
    func recognizesRightOptionShiftOnly() {
        #expect(activeSide([.rightOption, .rightShift]) == .right)
    }

    @Test
    func ignoresPartialPairs() {
        #expect(activeSide([.leftOption]) == nil)
        #expect(activeSide([.rightShift]) == nil)
    }

    @Test
    func ignoresMixedSides() {
        #expect(activeSide([.leftOption, .rightShift]) == nil)
        #expect(activeSide([.leftOption, .leftShift, .rightOption]) == nil)
        #expect(activeSide([.leftOption, .leftShift, .rightOption, .rightShift]) == nil)
    }

    @Test
    func commandControlOrFunctionSuppressHotkey() {
        #expect(activeSide([.leftOption, .leftShift, .leftCommand]) == nil)
        #expect(activeSide([.rightOption, .rightShift, .rightControl]) == nil)
        #expect(activeSide([.leftOption, .leftShift, .function]) == nil)
    }

    private func activeSide(_ pressed: Set<ModifierHotKey>) -> ModifierHotKeySide? {
        ModifierHotKeyPolicy.activeSide { pressed.contains($0) }
    }
}
