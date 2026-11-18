import AppKit
import BPViewerCore

extension SourceTextView.Coordinator {
    func scheduleSyntaxHighlighting(
        in textView: NSTextView,
        source: String,
        syntaxHighlighting: SourceSyntaxHighlighting?,
        delay: Duration = .milliseconds(120)
    ) {
        let request = SourceSyntaxHighlightingRequest(
            source: source,
            syntaxHighlighting: syntaxHighlighting
        )
        guard syntaxHighlightingGate.shouldSchedule(request) else {
            if syntaxHighlightingGate.applied == request {
                requiresSyntaxRefresh = false
            }
            return
        }
        syntaxHighlightTask?.cancel()
        syntaxHighlightGeneration += 1
        let generation = syntaxHighlightGeneration
        syntaxHighlightTask = Task { @MainActor [weak self, weak textView] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled,
                  let self,
                  let textView,
                  self.syntaxHighlightGeneration == generation else { return }

            let tokens = await Task.detached(priority: .utility) {
                syntaxHighlighting.map {
                    SourceSyntaxTokenizer.tokens(in: request.source, for: $0)
                } ?? []
            }.value
            guard !Task.isCancelled,
                  self.syntaxHighlightGeneration == generation,
                  textView.string == source else { return }
            SourceTextView.applySyntaxHighlighting(
                to: textView,
                source: request.source,
                syntaxHighlighting: syntaxHighlighting,
                tokens: tokens
            )
            self.syntaxHighlightTask = nil
            self.syntaxHighlightingGate.markApplied(request)
            self.requiresSyntaxRefresh = false
        }
    }

    func scheduleInitialSyntaxRefresh(
        in textView: NSTextView,
        source: String,
        syntaxHighlighting: SourceSyntaxHighlighting?
    ) {
        DispatchQueue.main.async { [weak self, weak textView] in
            guard let self,
                  let textView,
                  self.requiresInitialSyntaxRefresh,
                  textView.string == source else { return }

            self.requiresInitialSyntaxRefresh = false
            self.scheduleSyntaxHighlighting(
                in: textView,
                source: source,
                syntaxHighlighting: syntaxHighlighting,
                delay: .zero
            )
        }
    }
}
