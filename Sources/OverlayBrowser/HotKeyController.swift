import AppKit
import Carbon

final class HotKeyController {
    private static let signature = OSType(0x53465330) // SFS0

    private enum ModifierSide {
        case left
        case right
    }

    private struct HotKeyDefinition {
        let identifier: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let side: ModifierSide
        let label: String
    }

    private static let hotKeyDefinitions = [
        HotKeyDefinition(
            identifier: 1,
            keyCode: UInt32(kVK_Shift),
            modifiers: UInt32(optionKey),
            side: .left,
            label: "Left Option+Left Shift"
        ),
        HotKeyDefinition(
            identifier: 2,
            keyCode: UInt32(kVK_Option),
            modifiers: UInt32(shiftKey),
            side: .left,
            label: "Left Option+Left Shift"
        ),
        HotKeyDefinition(
            identifier: 3,
            keyCode: UInt32(kVK_RightShift),
            modifiers: UInt32(optionKey),
            side: .right,
            label: "Right Option+Right Shift"
        ),
        HotKeyDefinition(
            identifier: 4,
            keyCode: UInt32(kVK_RightOption),
            modifiers: UInt32(shiftKey),
            side: .right,
            label: "Right Option+Right Shift"
        )
    ]
    private static let leftShiftFlag = NSEvent.ModifierFlags.RawValue(0x00000002)
    private static let rightShiftFlag = NSEvent.ModifierFlags.RawValue(0x00000004)
    private static let leftOptionFlag = NSEvent.ModifierFlags.RawValue(0x00000020)
    private static let rightOptionFlag = NSEvent.ModifierFlags.RawValue(0x00000040)

    private let onPressed: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            writeHotKeyError("InstallEventHandler", status: handlerStatus)
            return
        }

        for definition in Self.hotKeyDefinitions {
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: definition.identifier
            )

            var hotKey: EventHotKeyRef?
            let registerStatus = RegisterEventHotKey(
                definition.keyCode,
                definition.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKey
            )

            if registerStatus == noErr, let hotKey {
                hotKeys.append(hotKey)
            } else {
                writeHotKeyError("RegisterEventHotKey \(definition.label)", status: registerStatus)
            }
        }
    }

    fileprivate func handleHotKeyPressed(event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard hotKeyID.signature == Self.signature,
              let definition = Self.hotKeyDefinitions.first(where: { $0.identifier == hotKeyID.id }),
              Self.activeModifierSide() == definition.side else {
            return noErr
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPressed()
        }

        return noErr
    }

    private static func activeModifierSide() -> ModifierSide? {
        let flags = NSEvent.modifierFlags
        let independentFlags = flags.intersection(.deviceIndependentFlagsMask)
        guard independentFlags.contains(.option), independentFlags.contains(.shift) else {
            return nil
        }

        guard independentFlags.intersection([.command, .control, .function]).isEmpty else {
            return nil
        }

        let rawFlags = flags.rawValue
        let isLeftPairActive = rawFlags & leftOptionFlag != 0 && rawFlags & leftShiftFlag != 0
        let isRightPairActive = rawFlags & rightOptionFlag != 0 && rawFlags & rightShiftFlag != 0
        let hasMixedSideFlags = rawFlags & (leftOptionFlag | leftShiftFlag | rightOptionFlag | rightShiftFlag)

        switch (isLeftPairActive, isRightPairActive, hasMixedSideFlags) {
        case (true, false, leftOptionFlag | leftShiftFlag):
            return .left
        case (false, true, rightOptionFlag | rightShiftFlag):
            return .right
        default:
            return nil
        }
    }

    private func writeHotKeyError(_ operation: String, status: OSStatus) {
        fputs("OverlayBrowser hotkey error: \(operation) failed with status \(status)\n", stderr)
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else {
        return noErr
    }

    let controller = Unmanaged<HotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()

    return controller.handleHotKeyPressed(event: event)
}
