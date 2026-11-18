import BPViewerCore
import Foundation

extension Runner {
    /// Pure rules of the terminal reader: terminal detection, client detection,
    /// copy-picker detection, and reply file naming.
    mutating func runTerminalReplyContracts() {
        expect(
            TerminalReplyRules.isTerminal(bundleIdentifier: "com.apple.Terminal"),
            "Terminal.app counts as a terminal"
        )
        expect(
            TerminalReplyRules.isTerminal(bundleIdentifier: "dev.warp.Warp-Stable"),
            "Warp counts as a terminal"
        )
        expect(
            !TerminalReplyRules.isTerminal(bundleIdentifier: "com.apple.Safari"),
            "a browser does not count as a terminal"
        )
        expect(
            !TerminalReplyRules.isTerminal(bundleIdentifier: nil),
            "a frontmost app without a bundle identifier is not a terminal"
        )

        var readsText = false
        expect(
            TerminalReplyRules.client(windowTitle: "‹ Claude") {
                readsText = true
                return nil
            } == .claudeCode && !readsText,
            "a Claude Code title identifies the client without reading the window text"
        )
        expect(
            TerminalReplyRules.client(windowTitle: "claude --resume") { nil } == .claudeCode,
            "a title with 'claude --' identifies Claude Code"
        )
        expect(
            TerminalReplyRules.client(windowTitle: "zsh") { "output\n❯ next prompt" } == .claudeCode,
            "a ❯ prompt line in the window text identifies Claude Code"
        )
        expect(
            TerminalReplyRules.client(windowTitle: "zsh") { "plain shell output" } == .codex,
            "a window without Claude Code markers defaults to Codex"
        )

        let picker = "Earlier text\nSelect content to copy:\n  Full response\n  Enter to copy"
        expect(
            TerminalReplyRules.isClaudeCopyPicker(in: picker),
            "the copy picker is detected from its prompt, full response, and enter option"
        )
        expect(
            !TerminalReplyRules.isClaudeCopyPicker(in: "Select content to copy:\n  Code block only"),
            "a picker without the full response option is not detected"
        )
        expect(
            !TerminalReplyRules.isClaudeCopyPicker(in: "Full response\nEnter to copy"),
            "text without the picker prompt is not detected"
        )

        expect(
            TerminalReplyRules.fileName(for: .codex, index: 1) == "Codex Reply.md",
            "the first Codex reply is named without a suffix"
        )
        expect(
            TerminalReplyRules.fileName(for: .claudeCode, index: 3) == "Claude Code Reply 3.md",
            "later Claude Code replies get a numeric suffix"
        )
        expect(
            TerminalReplyRules.nextFileName(for: .codex) { _ in false } == "Codex Reply.md",
            "the first free Codex name is the base name when nothing exists"
        )
        let taken: Set<String> = ["Codex Reply.md", "Codex Reply 2.md"]
        expect(
            TerminalReplyRules.nextFileName(for: .codex) { taken.contains($0) } == "Codex Reply 3.md",
            "the next Codex name skips existing numbered files"
        )
        expect(
            TerminalReplyRules.nextFileName(for: .claudeCode) { $0 == "Codex Reply.md" } == "Claude Code Reply.md",
            "naming for one client ignores files of the other client"
        )
        expect(
            TerminalReplyClient.codex.folderName == "Codex Responses"
                && TerminalReplyClient.claudeCode.folderName == "Claude Code Responses",
            "each client saves into its own Downloads folder"
        )
    }
}
