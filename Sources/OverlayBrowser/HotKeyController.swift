import AppKit
import Carbon

final class HotKeyController {
    private enum ModifierSide {
        case left
        case right
    }

    private static let pollingInterval: TimeInterval = 0.04
    private let onPressed: () -> Void
    private var pollingTimer: Timer?
    private var pressedSide: ModifierSide?

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        pollingTimer?.invalidate()
    }

    func register() {
        guard pollingTimer == nil else {
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            self?.pollModifierHotKey()
        }
        timer.tolerance = Self.pollingInterval / 2
        pollingTimer = timer
    }

    private static func activeModifierSide() -> ModifierSide? {
        guard !isKeyPressed(kVK_Command),
              !isKeyPressed(kVK_RightCommand),
              !isKeyPressed(kVK_Control),
              !isKeyPressed(kVK_RightControl),
              !isKeyPressed(kVK_Function) else {
            return nil
        }

        let leftPairActive = isKeyPressed(kVK_Option) && isKeyPressed(kVK_Shift)
        let rightPairActive = isKeyPressed(kVK_RightOption) && isKeyPressed(kVK_RightShift)
        let hasLeftSideModifier = isKeyPressed(kVK_Option) || isKeyPressed(kVK_Shift)
        let hasRightSideModifier = isKeyPressed(kVK_RightOption) || isKeyPressed(kVK_RightShift)

        switch (leftPairActive, rightPairActive, hasLeftSideModifier, hasRightSideModifier) {
        case (true, false, true, false):
            return .left
        case (false, true, false, true):
            return .right
        default:
            return nil
        }
    }

    private static func isKeyPressed(_ keyCode: Int) -> Bool {
        CGEventSource.keyState(.hidSystemState, key: CGKeyCode(keyCode))
    }

    private func pollModifierHotKey() {
        guard let activeSide = Self.activeModifierSide() else {
            pressedSide = nil
            return
        }

        guard pressedSide == nil else {
            return
        }

        pressedSide = activeSide
        onPressed()
    }
}
