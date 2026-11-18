import AppKit
import BPViewerCore

enum SourceEditorFindSelectionPolicy {
    static func shouldSelectMatch(query: String, matchCount: Int) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && matchCount > 0
    }
}

extension SourceTextView.Coordinator {
    func applyFind(
        in textView: NSTextView,
        source: String,
        query: String,
        requestID: Int,
        backwards: Bool,
        isFindTarget: Bool
    ) {
        guard isFindTarget else {
            clearFind(in: textView, notify: false)
            return
        }

        let sourceChanged = findSource != source
        let queryChanged = findQuery != query
        let requestChanged = findRequestID != requestID
        guard sourceChanged || queryChanged || requestChanged else { return }

        findSource = source
        findQuery = query
        findRequestID = requestID

        if sourceChanged || queryChanged {
            findMatches = TextSearch.matches(in: source, query: query)
            currentFindIndex = TextSearch.nextMatchIndex(
                currentIndex: nil,
                matchCount: findMatches.count,
                backwards: backwards
            )
        } else {
            currentFindIndex = TextSearch.nextMatchIndex(
                currentIndex: currentFindIndex,
                matchCount: findMatches.count,
                backwards: backwards
            )
        }

        onFindMatchCount(findMatches.count)
        updateFindHighlights(in: textView)
    }

    private func clearFind(in textView: NSTextView, notify: Bool) {
        if hasFindHighlights {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.layoutManager?.removeTemporaryAttribute(
                .backgroundColor,
                forCharacterRange: fullRange
            )
        }
        findSource = ""
        findQuery = ""
        findRequestID = -1
        findMatches = []
        currentFindIndex = nil
        hasFindHighlights = false
        if notify {
            onFindMatchCount(0)
        }
    }

    private func updateFindHighlights(in textView: NSTextView) {
        if hasFindHighlights {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.layoutManager?.removeTemporaryAttribute(
                .backgroundColor,
                forCharacterRange: fullRange
            )
        }

        for match in findMatches {
            let range = NSRange(
                location: match.utf16Range.lowerBound,
                length: match.utf16Range.count
            )
            textView.layoutManager?.addTemporaryAttribute(
                .backgroundColor,
                value: NSColor.controlAccentColor.withAlphaComponent(0.22),
                forCharacterRange: range
            )
        }
        hasFindHighlights = !findMatches.isEmpty

        guard SourceEditorFindSelectionPolicy.shouldSelectMatch(
            query: findQuery,
            matchCount: findMatches.count
        ) else {
            return
        }

        guard let currentFindIndex,
              findMatches.indices.contains(currentFindIndex) else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            return
        }

        let match = findMatches[currentFindIndex]
        let range = NSRange(
            location: match.utf16Range.lowerBound,
            length: match.utf16Range.count
        )
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }
}
