import Foundation

/// Raw HTML the Markdown preview renders as markup instead of the "HTML raw"
/// placeholder. Only a line break and bare formatting tags (no attributes) pass;
/// every other tag keeps the placeholder, so scripts and styling stay out.
public enum MarkdownSafeInlineHTML {
    public static let formattingTags: Set<String> = [
        "b", "strong", "i", "em", "u", "sub", "sup", "kbd", "mark", "code", "s", "del", "small"
    ]

    /// Renders one raw HTML tag token (`<br>`, `<br/>`, `<br />`, `<b>`, `</b>`, ...),
    /// or returns nil when the token is not in the allowlist.
    public static func inline(_ rawHTML: String) -> String? {
        let tag = rawHTML.lowercased()
        if tag.wholeMatch(of: /<br\s*\/?>/) != nil {
            return "<br />"
        }
        guard let match = tag.wholeMatch(of: /<(\/?)([a-z]+)>/),
              formattingTags.contains(String(match.output.2)) else {
            return nil
        }
        return "<\(match.output.1)\(match.output.2)>"
    }

    /// Renders a raw HTML block made only of allowlisted tags separated by whitespace,
    /// or returns nil when any other content is present.
    public static func block(_ rawHTML: String) -> String? {
        let tokens = rawHTML.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return nil }
        var rendered = ""
        for token in tokens {
            guard let tag = inline(String(token)) else { return nil }
            rendered += tag
        }
        return rendered
    }
}
