---
description: "The macOS SwiftUI and AppKit layer of Viewer: window composition, AppModel coordination, document surfaces and editors, and reply capture; logic that needs no UI framework belongs in Core."
---

# BPViewerApp

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->

## Artifact references

- [AppModel.swift](/Sources/BPViewerApp/AppModel.swift) coordinates UI intents, observable state, and session events.
- [SourceTextView.swift](/Sources/BPViewerApp/SourceTextView.swift) is the SwiftUI bridge of the source editor. Its AppKit parts are split by topic: `SourceTextView+*.swift` (appearance, commands, coordinator, offsets, source replacement, syntax highlighting), `MarkdownNSTextView*.swift` (the text view, its line fragments and gutter, paragraph styles, inline completion, list continuation), `SourceSyntax*.swift` (highlight requests and tokenizer), and `SourceEditorLayout.swift` (metrics).
- [TerminalReplyController.swift](/Sources/BPViewerApp/TerminalReader/TerminalReplyController.swift) runs the terminal reply capture engine in the `TerminalReader` folder; its boundary with the app is in `docs/technical/terminal-reader.md`.
