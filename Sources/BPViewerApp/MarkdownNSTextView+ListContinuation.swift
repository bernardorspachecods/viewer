import AppKit

extension MarkdownNSTextView {
    func continueMarkdownListIfNeeded() -> Bool {
        let source = string as NSString
        let selection = selectedRange()
        let caret = min(max(selection.location, 0), source.length)

        var lineStart = caret
        while lineStart > 0, source.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }
        var lineEnd = caret
        while lineEnd < source.length, source.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        let line = source.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart)) as NSString
        var markerStart = 0
        while markerStart < line.length, isHorizontalWhitespace(line.character(at: markerStart)) {
            markerStart += 1
        }
        guard markerStart < line.length else { return false }

        let firstMarkerCharacter = line.character(at: markerStart)
        var markerEnd: Int
        let continuedMarker: String
        if isMarkdownBulletMarker(firstMarkerCharacter) {
            markerEnd = markerStart + 1
            continuedMarker = line.substring(with: NSRange(location: markerStart, length: 1))
        } else {
            var digitsEnd = markerStart
            while digitsEnd < line.length,
                  (48...57).contains(line.character(at: digitsEnd)) {
                digitsEnd += 1
            }
            let digitCount = digitsEnd - markerStart
            guard (1...9).contains(digitCount),
                  digitsEnd < line.length,
                  line.character(at: digitsEnd) == 46 || line.character(at: digitsEnd) == 41,
                  let number = Int(line.substring(with: NSRange(
                    location: markerStart,
                    length: digitCount
                  ))) else { return false }
            let (nextNumber, overflow) = number.addingReportingOverflow(1)
            guard !overflow, nextNumber <= 999_999_999 else { return false }
            let nextNumberText = String(nextNumber)
            let leadingZeroes = String(repeating: "0", count: max(0, digitCount - nextNumberText.count))
            let punctuation = line.substring(with: NSRange(location: digitsEnd, length: 1))
            continuedMarker = leadingZeroes + nextNumberText + punctuation
            markerEnd = digitsEnd + 1
        }

        guard markerEnd < line.length, isHorizontalWhitespace(line.character(at: markerEnd)) else {
            return false
        }
        let whitespaceStart = markerEnd
        while markerEnd < line.length, isHorizontalWhitespace(line.character(at: markerEnd)) {
            markerEnd += 1
        }
        guard caret >= lineStart + markerEnd else { return false }

        let indentation = line.substring(to: markerStart)
        let markerWhitespace = line.substring(with: NSRange(
            location: whitespaceStart,
            length: markerEnd - whitespaceStart
        ))
        let markerPrefix = indentation + continuedMarker + markerWhitespace
        let itemText = line.substring(from: markerEnd)
        if itemText.trimmingCharacters(in: .whitespaces).isEmpty {
            let emptyItemRange = NSRange(location: lineStart, length: line.length)
            guard shouldChangeText(in: emptyItemRange, replacementString: "") else { return true }
            replaceCharacters(in: emptyItemRange, with: "")
            setSelectedRange(NSRange(location: lineStart, length: 0))
        } else {
            let insertion = "\n" + markerPrefix
            guard shouldChangeText(in: selection, replacementString: insertion) else { return true }
            replaceCharacters(in: selection, with: insertion)
            setSelectedRange(NSRange(location: caret + (insertion as NSString).length, length: 0))
        }
        didChangeText()
        return true
    }

    private func isMarkdownBulletMarker(_ character: unichar) -> Bool {
        character == 45 || character == 42 || character == 43
    }

    private func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == 32 || character == 9
    }
}
