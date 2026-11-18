import BPViewerCore
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Posts the keystrokes that ask the frontmost CLI for its latest reply.
enum TerminalReplyKeystrokes {
    /// Codex copies its latest reply with `Ctrl+O`; Claude Code runs `/copy`.
    static func sendCopyCommand(for client: TerminalReplyClient) -> Bool {
        client == .claudeCode ? sendClaudeCopyCommand() : sendCodexCopyShortcut()
    }

    static func sendReturnKey() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Return),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Return),
                keyDown: false
              ) else {
            return false
        }

        keyDown.flags = []
        keyUp.flags = []
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func sendClaudeCopyCommand() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let textKeyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_Slash),
                keyDown: true
              ),
              let textKeyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_Slash),
                keyDown: false
              ),
              let returnKeyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Return),
                keyDown: true
              ),
              let returnKeyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Return),
                keyDown: false
              ) else {
            return false
        }

        // Override held shortcut modifiers and keyboard layout for /copy.
        textKeyDown.flags = []
        textKeyUp.flags = []
        let commandCharacters = Array("/copy".utf16)
        commandCharacters.withUnsafeBufferPointer { characters in
            textKeyDown.keyboardSetUnicodeString(
                stringLength: characters.count,
                unicodeString: characters.baseAddress
            )
        }
        textKeyDown.post(tap: .cghidEventTap)
        textKeyUp.post(tap: .cghidEventTap)

        // Give the slash-command menu time to recognize the command.
        Thread.sleep(forTimeInterval: 0.15)
        returnKeyDown.flags = []
        returnKeyUp.flags = []
        returnKeyDown.post(tap: .cghidEventTap)
        returnKeyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func sendCodexCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_O),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_O),
                keyDown: false
              ) else {
            return false
        }

        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
