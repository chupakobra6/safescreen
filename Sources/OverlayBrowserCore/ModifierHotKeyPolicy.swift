public enum ModifierHotKey: Hashable {
    case leftOption
    case rightOption
    case leftShift
    case rightShift
    case leftCommand
    case rightCommand
    case leftControl
    case rightControl
    case function
}

public enum ModifierHotKeySide: Equatable {
    case left
    case right
}

public enum ModifierHotKeyPolicy {
    public static func activeSide(isPressed: (ModifierHotKey) -> Bool) -> ModifierHotKeySide? {
        guard !isPressed(.leftCommand),
              !isPressed(.rightCommand),
              !isPressed(.leftControl),
              !isPressed(.rightControl),
              !isPressed(.function) else {
            return nil
        }

        let leftPairActive = isPressed(.leftOption) && isPressed(.leftShift)
        let rightPairActive = isPressed(.rightOption) && isPressed(.rightShift)
        let hasLeftSideModifier = isPressed(.leftOption) || isPressed(.leftShift)
        let hasRightSideModifier = isPressed(.rightOption) || isPressed(.rightShift)

        switch (leftPairActive, rightPairActive, hasLeftSideModifier, hasRightSideModifier) {
        case (true, false, true, false):
            return .left
        case (false, true, false, true):
            return .right
        default:
            return nil
        }
    }
}
