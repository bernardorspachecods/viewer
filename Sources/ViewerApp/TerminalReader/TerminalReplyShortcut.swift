import AppKit
import Carbon.HIToolbox

private let replyHotKeySignature = OSType(0x42505652) // BPVR

extension TerminalReplyDestination {
    var modifiers: NSEvent.ModifierFlags {
        switch self {
        case .readerWindow: [.command, .shift]
        case .workspaceTab: [.command, .option]
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .readerWindow: UInt32(cmdKey | shiftKey)
        case .workspaceTab: UInt32(cmdKey | optionKey)
        }
    }

    var label: String {
        switch self {
        case .readerWindow: "⇧⌘E"
        case .workspaceTab: "⌥⌘E"
        }
    }
}

/// Registers the global `⇧⌘E` and `⌥⌘E` shortcuts and reports which one was
/// pressed. Carbon hot keys are the primary path; a global key monitor is the
/// fallback for combinations another app has claimed.
@MainActor
final class TerminalReplyShortcut {
    /// Called on the main actor for each press.
    var onPress: ((TerminalReplyDestination) -> Void)?

    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var globalKeyMonitor: Any?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var pressedHotKey = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedHotKey
                )
                guard parameterStatus == noErr,
                      pressedHotKey.signature == replyHotKeySignature,
                      let destination = TerminalReplyDestination(rawValue: pressedHotKey.id) else {
                    return OSStatus(eventNotHandledErr)
                }

                let shortcut = Unmanaged<TerminalReplyShortcut>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    shortcut.onPress?(destination)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            NSLog("Viewer could not install its global reply shortcut handler: %d", handlerStatus)
            return
        }

        for destination in TerminalReplyDestination.allCases {
            let identifier = EventHotKeyID(
                signature: replyHotKeySignature,
                id: destination.rawValue
            )
            var hotKey: EventHotKeyRef?
            let registrationStatus = RegisterEventHotKey(
                UInt32(kVK_ANSI_E),
                destination.carbonModifiers,
                identifier,
                GetApplicationEventTarget(),
                0,
                &hotKey
            )
            if registrationStatus == noErr, let hotKey {
                hotKeys.append(hotKey)
            } else {
                NSLog("Viewer could not register %@: %d", destination.label, registrationStatus)
            }
        }

        // Carbon hotkeys can fail to register when another app has claimed the
        // same combination. Keep a global event monitor as a fallback.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard event.keyCode == UInt16(kVK_ANSI_E),
                  let destination = TerminalReplyDestination.allCases.first(where: { $0.modifiers == flags }) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.onPress?(destination)
            }
        }
    }

    func unregister() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }
}
