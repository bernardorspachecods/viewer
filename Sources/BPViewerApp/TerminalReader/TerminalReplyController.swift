import AppKit
import BPViewerCore
import Foundation

/// Captures the latest reply of a terminal CLI (Codex or Claude Code), saves it
/// as Markdown, and asks the app to open it. It owns the capture flow; the app
/// owns the windows, reached only through `TerminalReplyHost`.
@MainActor
final class TerminalReplyController {
    private let windows: any TerminalReplyHost
    private let shortcut = TerminalReplyShortcut()
    /// Poll attempt (100 ms each) at which a blind Return confirms Claude Code's
    /// copy picker when it was not detected.
    private static let claudePickerFallbackAttempt = 6
    private var isCapturing = false
    private var didRequestAccessibilityPermission = false
    private var lastShortcutHandledAt: TimeInterval = 0

    init(windows: any TerminalReplyHost) {
        self.windows = windows
        shortcut.onPress = { [weak self] destination in
            self?.handleShortcutPress(destination)
        }
    }

    func registerGlobalShortcut() {
        shortcut.register()
    }

    func unregisterGlobalShortcut() {
        shortcut.unregister()
    }

    private func handleShortcutPress(_ destination: TerminalReplyDestination) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastShortcutHandledAt > 0.4 else { return }
        lastShortcutHandledAt = now
        captureLatestReply(destination: destination)
    }

    private func captureLatestReply(destination: TerminalReplyDestination) {
        guard !isCapturing else { return }
        guard let terminal = NSWorkspace.shared.frontmostApplication,
              TerminalReplyRules.isTerminal(bundleIdentifier: terminal.bundleIdentifier) else {
            showAlert(
                title: "Open Codex or Claude Code in a Terminal",
                message: "Focus the terminal running Codex or Claude Code CLI, then press ⇧⌘E (new window) or ⌥⌘E (current workspace)."
            )
            return
        }

        guard requestAccessibilityPermissionIfNeeded() else { return }
        let client = TerminalReplyAccessibility.client(for: terminal.processIdentifier)
        let originalClipboardChangeCount = NSPasteboard.general.changeCount
        let didSendCopyCommand = TerminalReplyKeystrokes.sendCopyCommand(for: client)
        guard didSendCopyCommand else {
            showAlert(
                title: "Couldn’t Copy the \(client.displayName) Reply",
                message: "BP Viewer could not request the \(client.displayName) reply. Check its Accessibility permission in System Settings and try again."
            )
            return
        }

        isCapturing = true
        let terminalProcessID = terminal.processIdentifier
        Task { @MainActor [weak self] in
            var didSelectClaudeCopyOption = false
            for attempt in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == terminalProcessID else {
                    self.isCapturing = false
                    return
                }

                if client == .claudeCode,
                   !didSelectClaudeCopyOption,
                   TerminalReplyAccessibility.isClaudeCopyPickerVisible(in: terminalProcessID) {
                    didSelectClaudeCopyOption = TerminalReplyKeystrokes.sendReturnKey()
                } else if client == .claudeCode,
                          !didSelectClaudeCopyOption,
                          attempt == Self.claudePickerFallbackAttempt,
                          NSPasteboard.general.changeCount == originalClipboardChangeCount {
                    // The picker was not detected (wording or Accessibility text
                    // changed) and nothing was copied: confirm "Full response"
                    // blindly. Return on an empty Claude Code prompt does nothing.
                    didSelectClaudeCopyOption = TerminalReplyKeystrokes.sendReturnKey()
                }

                let clipboard = NSPasteboard.general
                guard clipboard.changeCount != originalClipboardChangeCount,
                      let response = clipboard.string(forType: .string),
                      !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }

                self.isCapturing = false
                self.openResponse(response, from: client, destination: destination)
                return
            }

            guard let self else { return }
            self.isCapturing = false
            let message = client == .claudeCode
                ? "If Claude Code opened its copy picker, select a response there. Otherwise make sure it is focused and has a completed reply, then try again."
                : "Make sure Codex CLI is focused and has a completed reply, then try again."
            self.showAlert(
                title: "No \(client.displayName) Reply Was Copied",
                message: message
            )
        }
    }

    /// Opens the window first, then saves the reply into it. A failed save leaves
    /// the window open with its document unsaved.
    private func openResponse(
        _ response: String,
        from client: TerminalReplyClient,
        destination: TerminalReplyDestination
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let target = windows.showReplyWindow(for: destination) else {
                showAlert(
                    title: "BP Viewer Has No Active Workspace",
                    message: "BP Viewer could not restore its window. Open the app and try the shortcut again."
                )
                return
            }
            do {
                let destinationURL = try TerminalReplyFiles.nextReplyURL(for: client)
                guard await target.saveReply(markdown: response, to: destinationURL) else {
                    showAlert(
                        title: "Couldn’t Save the \(client.displayName) Reply",
                        message: "The response remains open in an unsaved tab. Check that BP Viewer can write to Downloads/\(client.folderName)."
                    )
                    return
                }
            } catch {
                showAlert(
                    title: "Couldn’t Save the \(client.displayName) Reply",
                    message: "BP Viewer couldn’t find your Downloads folder. The response remains open in an unsaved tab."
                )
            }
        }
    }

    private func requestAccessibilityPermissionIfNeeded() -> Bool {
        guard !AXIsProcessTrusted() else { return true }

        // macOS displays its own Accessibility prompt each time this is called
        // with AXTrustedCheckOptionPrompt. A global shortcut can be pressed
        // repeatedly, so only ask once per app session.
        guard !didRequestAccessibilityPermission else {
            showAlert(
                title: "Restart Viewer to Apply Accessibility Access",
                message: "After enabling Viewer in System Settings → Privacy & Security → Accessibility, quit and reopen Viewer, then try ⇧⌘E again. macOS can keep the previous permission state for an app that is already running."
            )
            return false
        }
        didRequestAccessibilityPermission = true

        NSApp.activate(ignoringOtherApps: true)
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
