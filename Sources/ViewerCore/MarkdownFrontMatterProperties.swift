import Foundation

/// The `key: value` pairs of a simple front matter block, for showing it as a property list.
public enum MarkdownFrontMatterProperties {
    /// The pairs of `source` (the whole block, delimiters included), or nil when the block is
    /// more than flat `key: value` lines (lists, nested maps, block scalars), in which case
    /// the caller shows it as text. An indented line continues the previous value.
    public static func parse(_ source: String) -> [(key: String, value: String)]? {
        var lines = source.components(separatedBy: .newlines)
        guard lines.count >= 2,
              lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let last = lines.last?.trimmingCharacters(in: .whitespaces),
              last == "---" || last == "..." else { return nil }
        lines.removeFirst()
        lines.removeLast()

        var pairs: [(key: String, value: String)] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if let first = line.first, first == " " || first == "\t" {
                guard !pairs.isEmpty else { return nil }
                let continuation = line.trimmingCharacters(in: .whitespaces)
                guard !continuation.hasPrefix("- "), !continuation.hasPrefix("#") else { return nil }
                let previous = pairs[pairs.count - 1]
                pairs[pairs.count - 1] = (previous.key, previous.value + " " + continuation)
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let key = String(line[..<colon])
            guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else {
                return nil
            }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value == "|" || value == ">" || value == "|-" || value == ">-" { return nil }
            pairs.append((key, value))
        }
        // A key with no value whose next lines are indented is a nested map or a list.
        guard !pairs.isEmpty, !pairs.contains(where: { $0.value.isEmpty }) else { return nil }
        return pairs.map { ($0.key, unquoted($0.value)) }
    }

    private static func unquoted(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
}
