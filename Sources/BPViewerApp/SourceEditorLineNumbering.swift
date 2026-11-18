import AppKit

enum SourceEditorLineNumbering {
    static func lineCount(in source: String) -> Int {
        source.utf16.reduce(into: 1) { count, codeUnit in
            if codeUnit == 10 {
                count += 1
            }
        }
    }

    static func lineNumber(atUTF16Offset offset: Int, in source: String) -> Int {
        let sourceNSString = source as NSString
        let clampedOffset = min(max(offset, 0), sourceNSString.length)
        let prefix = sourceNSString.substring(to: clampedOffset)
        return lineCount(in: prefix)
    }
}
