import Foundation

/// A terminal CLI whose latest reply the terminal reader can capture.
public enum TerminalReplyClient: Sendable, Equatable {
    case codex
    case claudeCode

    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }

    /// Folder under Downloads that holds this client's saved replies.
    public var folderName: String {
        switch self {
        case .codex: "Codex Responses"
        case .claudeCode: "Claude Code Responses"
        }
    }

    public var fileBaseName: String {
        switch self {
        case .codex: "Codex Reply"
        case .claudeCode: "Claude Code Reply"
        }
    }
}

/// UI-independent rules of the terminal reader: which apps count as terminals,
/// which CLI a window shows, and how saved replies are named.
public enum TerminalReplyRules {
    public static let terminalBundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "org.wezfurlong.wezterm",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable"
    ]

    public static func isTerminal(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return terminalBundleIdentifiers.contains(bundleIdentifier)
    }

    /// Claude Code shows its name in the window title, or a `❯` prompt line in
    /// its text. Anything else is treated as Codex. `windowText` is read only
    /// when the title does not already identify Claude Code.
    public static func client(
        windowTitle: String,
        windowText: () -> String?
    ) -> TerminalReplyClient {
        let title = windowTitle.lowercased()
        if title.contains("‹ claude") || title.contains("claude --") {
            return .claudeCode
        }
        if let text = windowText(),
           text.components(separatedBy: "\n").contains(where: {
               $0.trimmingCharacters(in: .whitespaces).first == "❯"
           }) {
            return .claudeCode
        }
        return .codex
    }

    /// Claude Code's copy picker: a "Select content to copy:" prompt that offers
    /// "Full response" and "Enter to copy".
    public static func isClaudeCopyPicker(in text: String) -> Bool {
        guard let promptRange = text.range(of: "Select content to copy:", options: .caseInsensitive) else {
            return false
        }
        let pickerText = text[promptRange.lowerBound...]
        return pickerText.range(of: "Full response", options: .caseInsensitive) != nil
            && pickerText.range(of: "Enter to copy", options: .caseInsensitive) != nil
    }

    /// File name of the reply at `index` (1 is the first): the base name, then
    /// a numeric suffix from 2 on.
    public static func fileName(for client: TerminalReplyClient, index: Int) -> String {
        index == 1 ? "\(client.fileBaseName).md" : "\(client.fileBaseName) \(index).md"
    }

    /// The first file name for `client` that `exists` does not report as taken.
    public static func nextFileName(
        for client: TerminalReplyClient,
        exists: (String) -> Bool
    ) -> String {
        var index = 1
        while exists(fileName(for: client, index: index)) {
            index += 1
        }
        return fileName(for: client, index: index)
    }
}
