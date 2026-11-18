import AppKit
import BPViewerCore

extension SourceTextView.Coordinator {
    func cancelInlineCompletion(for textView: MarkdownNSTextView) {
        inlineCompletionTask?.cancel()
        inlineCompletionTask = nil
        inlineCompletionGeneration += 1
        textView.inlineCompletion = nil
    }

    func scheduleInlineCompletion(for textView: MarkdownNSTextView) {
        let suppressNextCompletion = textView.suppressInlineCompletionAfterAcceptance
        textView.suppressInlineCompletionAfterAcceptance = false
        cancelInlineCompletion(for: textView)
        guard !suppressNextCompletion,
              textView.usesMarkdownInlineCompletion,
              textView.isEditable,
              textView.selectedRange().length == 0 else { return }

        let source = textView.string
        let caret = textView.selectedRange().location
        guard MarkdownInlineCompletionProvider.eligibleWord(
            in: source,
            caretUTF16Offset: caret
        ) != nil else { return }

        let generation = inlineCompletionGeneration
        inlineCompletionTask = Task { @MainActor [weak self, weak textView] in
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  let textView,
                  self.inlineCompletionGeneration == generation,
                  textView.string == source,
                  textView.selectedRange() == NSRange(location: caret, length: 0) else { return }

            let completion = await MarkdownInlineCompletionProvider.completion(
                in: source,
                caretUTF16Offset: caret
            )
            guard !Task.isCancelled,
                  self.inlineCompletionGeneration == generation,
                  textView.string == source,
                  textView.selectedRange() == NSRange(location: caret, length: 0) else { return }
            textView.inlineCompletion = completion
            self.inlineCompletionTask = nil
        }
    }
}
