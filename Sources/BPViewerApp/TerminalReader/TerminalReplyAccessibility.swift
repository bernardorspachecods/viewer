import ApplicationServices
import BPViewerCore
import Foundation

/// Reads the focused terminal window through the Accessibility API to tell
/// which CLI is running and whether Claude Code's copy picker is open.
enum TerminalReplyAccessibility {
    static func client(for processIdentifier: pid_t) -> TerminalReplyClient {
        guard let window = focusedWindow(of: processIdentifier) else { return .codex }
        let title = accessibilityString(window, kAXTitleAttribute as CFString) ?? ""
        return TerminalReplyRules.client(windowTitle: title) {
            accessibilityText(in: window)
        }
    }

    static func isClaudeCopyPickerVisible(in processIdentifier: pid_t) -> Bool {
        guard let window = focusedWindow(of: processIdentifier),
              let text = accessibilityText(in: window) else {
            return false
        }
        return TerminalReplyRules.isClaudeCopyPicker(in: text)
    }

    private static func focusedWindow(of processIdentifier: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success, let focusedWindow else { return nil }
        return unsafeDowncast(focusedWindow, to: AXUIElement.self)
    }

    private static func accessibilityString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    /// The value of the first text area found in the element's subtree.
    private static func accessibilityText(in element: AXUIElement) -> String? {
        if accessibilityString(element, kAXRoleAttribute as CFString) == kAXTextAreaRole,
           let value = accessibilityString(element, kAXValueAttribute as CFString) {
            return value
        }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success,
        let children = childrenValue as? [AXUIElement] else { return nil }

        for child in children {
            if let value = accessibilityText(in: child) { return value }
        }
        return nil
    }
}
