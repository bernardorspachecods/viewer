---
description: "UI-independent Viewer logic: filesystem scanning, session and tab models, document opening, Markdown, LaTeX, JSON and CSV adapters, diffs, and editing merges."
---

# ViewerCore

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->

## Artifact references

- [FileSystemFoundation.swift](/Sources/ViewerCore/FileSystemFoundation.swift) defines document types and recursive filesystem scanning.
- [FolderCollapseRules.swift](/Sources/ViewerCore/FolderCollapseRules.swift) holds the sidebar folder collapse button's step rules.
- [BuildChannel.swift](/Sources/ViewerCore/BuildChannel.swift) decides whether the running build is the release channel or a development build (DEV label).
- [AppShortcutCatalog.swift](/Sources/ViewerCore/AppShortcutCatalog.swift) defines every keyboard shortcut the app responds to; the menu commands and the Settings Shortcuts tab both read it.
- [WorkspaceSessionCoordinator.swift](/Sources/ViewerCore/WorkspaceSessionCoordinator.swift) coordinates workspace state, persistence, permissions, and snapshots.
- [DocumentOpenCoordinator.swift](/Sources/ViewerCore/DocumentOpenCoordinator.swift) resolves URLs, supported types, and LaTeX context.
- [MarkdownAdapter.swift](/Sources/ViewerCore/MarkdownAdapter.swift) renders Markdown previews.
- [LatexAdapter.swift](/Sources/ViewerCore/LatexAdapter.swift) runs LaTeX preview compilation.
- [JSONAdapter.swift](/Sources/ViewerCore/JSONAdapter.swift) validates and formats JSON previews.
- [CSVAdapter.swift](/Sources/ViewerCore/CSVAdapter.swift) parses CSV and generates preview HTML.
- [DocumentDiff.swift](/Sources/ViewerCore/DocumentDiff.swift) provides diff modes, baselines, providers, and comparison logic; the Git HEAD baseline and restore are in `GitHeadDocumentDiff.swift`.

Keep public contracts aligned with [current app behavior](/docs/MAP.md). Runners exercise this module before relying on UI behavior.
