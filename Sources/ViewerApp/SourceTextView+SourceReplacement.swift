import AppKit

extension SourceTextView {
    static func replaceSourcePreservingUnchangedAttributes(
        _ source: String,
        in textView: NSTextView,
        selection: NSRange
    ) -> NSRange {
        guard let textStorage = textView.textStorage else {
            textView.string = source
            return NSRange(
                location: min(selection.location, (source as NSString).length),
                length: 0
            )
        }

        let currentSource = textView.string as NSString
        let replacementSource = source as NSString
        let currentLength = currentSource.length
        let replacementLength = replacementSource.length
        let sharedLength = min(currentLength, replacementLength)
        var commonPrefixLength = 0

        while commonPrefixLength < sharedLength,
              currentSource.character(at: commonPrefixLength)
                == replacementSource.character(at: commonPrefixLength) {
            commonPrefixLength += 1
        }

        // Keep the edit range on UTF-16 scalar boundaries so an undo that
        // touches emoji does not leave half of a surrogate pair behind.
        if commonPrefixLength > 0,
           commonPrefixLength < currentLength,
           isLowSurrogate(currentSource.character(at: commonPrefixLength)) {
            commonPrefixLength -= 1
        }

        var commonSuffixLength = 0
        while commonSuffixLength < currentLength - commonPrefixLength,
              commonSuffixLength < replacementLength - commonPrefixLength,
              currentSource.character(at: currentLength - commonSuffixLength - 1)
                == replacementSource.character(at: replacementLength - commonSuffixLength - 1) {
            commonSuffixLength += 1
        }

        if commonSuffixLength > 0 {
            let currentSuffixStart = currentLength - commonSuffixLength
            let replacementSuffixStart = replacementLength - commonSuffixLength
            if (currentSuffixStart < currentLength
                && isLowSurrogate(currentSource.character(at: currentSuffixStart)))
                || (replacementSuffixStart < replacementLength
                    && isLowSurrogate(replacementSource.character(at: replacementSuffixStart))) {
                commonSuffixLength -= 1
            }
        }

        let currentRange = NSRange(
            location: commonPrefixLength,
            length: currentLength - commonPrefixLength - commonSuffixLength
        )
        let replacementRange = NSRange(
            location: commonPrefixLength,
            length: replacementLength - commonPrefixLength - commonSuffixLength
        )
        guard currentRange.length > 0 || replacementRange.length > 0 else { return selection }

        let currentEnd = NSMaxRange(currentRange)
        let replacementEnd = NSMaxRange(replacementRange)
        let lengthDelta = replacementRange.length - currentRange.length

        func mappedOffset(_ offset: Int) -> Int {
            if currentRange.length == 0 {
                if offset < currentRange.location { return offset }
                if offset == currentRange.location {
                    return selection.length == 0 ? replacementEnd : currentRange.location
                }
                return offset + lengthDelta
            }
            if offset <= currentRange.location { return offset }
            if offset >= currentEnd { return offset + lengthDelta }
            return replacementEnd
        }

        let selectionStart = mappedOffset(selection.location)
        let selectionEnd = mappedOffset(NSMaxRange(selection))
        let updatedSelection = NSRange(
            location: min(selectionStart, selectionEnd),
            length: abs(selectionEnd - selectionStart)
        )

        textStorage.replaceCharacters(
            in: currentRange,
            with: replacementSource.substring(with: replacementRange)
        )
        return updatedSelection
    }

    private static func isLowSurrogate(_ codeUnit: unichar) -> Bool {
        (0xDC00...0xDFFF).contains(codeUnit)
    }
}
