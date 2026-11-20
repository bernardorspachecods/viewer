import AppKit
import ViewerCore
import WebKit

/// Copy on select for previews: a finished mouse selection is written to the general
/// pasteboard without Cmd+C. The setting is one global value; `AppModel` keeps
/// `isEnabled` in step with it. Source editors and editable fields never use this.
@MainActor
enum CopyOnSelect {
    static var isEnabled = true

    /// Script message name the injected script posts to.
    nonisolated static let messageName = "viewerCopyOnSelect"

    /// Writes the selection when the setting allows it and the selection has text.
    static func copy(_ selection: String?) {
        guard let text = CopyOnSelectRule.textToCopy(selection, enabled: isEnabled) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Adds the mouse-up listener and its message handler to a web view configuration.
    static func install(in configuration: WKWebViewConfiguration) {
        configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        configuration.userContentController.add(CopyOnSelectMessageHandler.shared, name: messageName)
    }

    /// Posts the selected text on mouse-up, not on every selection change, so a
    /// half-finished drag is never copied. Editable content is skipped.
    private static let script = """
    (function () {
      function isEditable(node) {
        var el = node && node.nodeType === 1 ? node : (node && node.parentElement);
        while (el) {
          if (el.isContentEditable || el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') return true;
          el = el.parentElement;
        }
        return false;
      }
      document.addEventListener('mouseup', function () {
        var selection = window.getSelection();
        if (!selection || selection.isCollapsed) return;
        if (isEditable(selection.anchorNode) || isEditable(selection.focusNode)) return;
        if (isEditable(document.activeElement)) return;
        var text = selection.toString();
        if (!text || !text.trim()) return;
        window.webkit.messageHandlers.\(messageName).postMessage(text);
      }, true);
    })();
    """
}

/// Receives selected text from the injected script. WebKit delivers messages on the main thread.
final class CopyOnSelectMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = CopyOnSelectMessageHandler()

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == CopyOnSelect.messageName, let text = message.body as? String else { return }
        Task { @MainActor in
            CopyOnSelect.copy(text)
        }
    }
}
