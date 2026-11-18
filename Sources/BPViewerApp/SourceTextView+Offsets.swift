import AppKit

extension SourceTextView {
    static func utf8Offset(in source: String, utf16Offset: Int) -> Int {
        let sourceNSString = source as NSString
        let clampedOffset = min(max(utf16Offset, 0), sourceNSString.length)
        return sourceNSString.substring(to: clampedOffset).utf8.count
    }

    static func utf16Offsets(in source: String) -> [Int] {
        var offsets = Array(repeating: 0, count: source.utf8.count + 1)
        var utf8Offset = 0
        var utf16Offset = 0

        for scalar in source.unicodeScalars {
            let utf8Length = scalar.utf8.count
            let utf16Length = scalar.utf16.count
            for offset in utf8Offset..<(utf8Offset + utf8Length) {
                offsets[offset] = utf16Offset
            }
            utf8Offset += utf8Length
            utf16Offset += utf16Length
            offsets[utf8Offset] = utf16Offset
        }
        return offsets
    }

    static func utf16Offset(in source: String, utf8Offset: Int) -> Int {
        let bytes = Array(source.utf8)
        let clampedOffset = min(max(utf8Offset, 0), bytes.count)
        let prefix = String(decoding: bytes[..<clampedOffset], as: UTF8.self)
        return prefix.utf16.count
    }
}
