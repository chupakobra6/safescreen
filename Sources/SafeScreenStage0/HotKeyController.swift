import AppKit
import Carbon

final class HotKeyController {
    private static let signature = OSType(0x53465330) // SFS0
    private static let identifier = UInt32(1)

    private let onPressed: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        if let hotKey {
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

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )

        let modifiers = UInt32(optionKey) | UInt32(shiftKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )

        if registerStatus != noErr {
            writeHotKeyError("RegisterEventHotKey", status: registerStatus)
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

        guard hotKeyID.signature == Self.signature, hotKeyID.id == Self.identifier else {
            return noErr
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPressed()
        }

        return noErr
    }

    private func writeHotKeyError(_ operation: String, status: OSStatus) {
        fputs("SafeScreenStage0 hotkey error: \(operation) failed with status \(status)\n", stderr)
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
