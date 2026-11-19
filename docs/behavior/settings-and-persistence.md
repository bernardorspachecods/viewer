---
bkf: document
description: "User-visible settings (theme, zoom defaults, window opening sizes, shell escape, default workspace folders, file types) and what the app keeps or drops across restarts."
tags: [behavior, settings, persistence]
---

# Settings and persistence

## Settings

- Theme.
- Markdown text width (Appearance tab): by default the text runs to the window edges;
  one switch keeps it in a centered column instead. It applies to every window and is
  kept in the app's defaults. Details are in [markdown.md](/docs/behavior/markdown.md).
- Default zoom levels.
- `shell escape` mode for LaTeX. It is off by default and changes only by an explicit
  choice here. See [security.md](/docs/technical/security.md).
- Workspaces tab: the "On Launch" choice (reopen the last workspaces, or always open
  the default workspaces), and the default workspace folders. Add folders with
  `Add Folder…` and remove them with the minus button. Their launch behavior is in
  [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- Windows tab: choose whether the workspace window remembers its last size (the
  default) or uses a custom width and height. Set the `⇧⌘E` reader size separately.
  Apply saves the changes for windows opened afterward. Dimensions are in points,
  with a standard size of 1200 × 780 and a minimum of 900 × 600. Custom sizes fit the
  display's available area as far as the minimum allows.
- Files tab: the file types the tree shows. Two sections:
  - "Supported by Viewer": Markdown, LaTeX, JSON, CSV, Word, PDF, and images. These
    are the only types Viewer opens itself. All are on by default.
  - "Other types": extensions you add (for example `txt`), shown in the tree and
    opened in the macOS default app. An extension Viewer already supports, an
    invalid one, or a duplicate is rejected. Extensions are case-insensitive.
  See [file-tree.md](/docs/behavior/file-tree.md).

## Kept across restarts

- Open workspaces, their order, and the active workspace.
- Per workspace: document tabs, the active tab, LaTeX root selection and context,
  the tree filter, expansion, whether the workspace root's listing is hidden, and
  the show-selected-files toggle.
- Per document: zoom, outline width and visibility, and reading position.
- Global: theme, sidebar width and visibility, default zoom levels, window opening
  preferences, `shell escape`, launch choice, default workspace folders, selected
  file types, and extra extensions.
- Snapshots, until you close them.

## Not kept across restarts

- Untitled `+` tabs.
- Open diffs. Rendered output, PDFs, logs, and raw content are not stored as session
  state; see [persistence.md](/docs/technical/persistence.md).
