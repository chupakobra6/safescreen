import AppKit
import Carbon
import OverlayBrowserCore

final class HotKeyController {
    private static let pollingInterval: TimeInterval = 0.04
    private let onPressed: () -> Void
    private var pollingTimer: Timer?
    private var pressedSide: ModifierHotKeySide?

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
        AppLog.info(.hotKey, "polling-start", ["interval": "\(Self.pollingInterval)"])
    }

    private static func activeModifierSide() -> ModifierHotKeySide? {
        ModifierHotKeyPolicy.activeSide { key in
            switch key {
            case .leftOption:
                return isKeyPressed(kVK_Option)
            case .rightOption:
                return isKeyPressed(kVK_RightOption)
            case .leftShift:
                return isKeyPressed(kVK_Shift)
            case .rightShift:
                return isKeyPressed(kVK_RightShift)
            case .leftCommand:
                return isKeyPressed(kVK_Command)
            case .rightCommand:
                return isKeyPressed(kVK_RightCommand)
            case .leftControl:
                return isKeyPressed(kVK_Control)
            case .rightControl:
                return isKeyPressed(kVK_RightControl)
            case .function:
                return isKeyPressed(kVK_Function)
            }
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
        AppLog.info(.hotKey, "trigger", ["side": activeSide == .left ? "left" : "right"])
        onPressed()
    }
}
