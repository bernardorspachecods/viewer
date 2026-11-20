/// Copy on select: which selected text is written to the pasteboard. Empty or
/// whitespace-only selections never reach the pasteboard, so a stray click cannot
/// clear what the user copied earlier.
public enum CopyOnSelectRule {
    /// The text to copy, or nil when nothing should be written (setting off, or no text selected).
    public static func textToCopy(_ selection: String?, enabled: Bool) -> String? {
        guard enabled, let selection,
              !selection.allSatisfy(\.isWhitespace) else { return nil }
        return selection
    }
}
