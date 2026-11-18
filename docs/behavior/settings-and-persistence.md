---
bkf: document
description: "User-visible settings (theme, zoom defaults, shell escape, default workspace folders, file types) and what the app keeps or drops across restarts."
tags: [behavior, settings, persistence]
---

# Settings and persistence

## Settings

- Theme.
- Default zoom levels.
- `shell escape` mode for LaTeX. It is off by default and changes only by an explicit
  choice here. See [security.md](/docs/technical/security.md).
- Workspaces tab: the default workspace folders. Add folders with `Add Folder…` and
  remove them with the minus button. Their launch behavior is in
  [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- Files tab: the file types the tree shows. By default these are Markdown, LaTeX,
  JSON, CSV, Word, PDF, and images. See [file-tree.md](/docs/behavior/file-tree.md).

## Kept across restarts

- Open workspaces, their order, and the active workspace.
- Per workspace: document tabs, the active tab, LaTeX root selection and context,
  the tree filter, expansion, whether the workspace root's listing is hidden, and
  the show-selected-files toggle.
- Per document: zoom, outline width and visibility, and reading position.
- Global: theme, sidebar width and visibility, default zoom levels, `shell escape`,
  default workspace folders, and selected file types.
- Snapshots, until you close them.

## Not kept across restarts

- Untitled `+` tabs.
- Open diffs. Rendered output, PDFs, logs, and raw content are not stored as session
  state; see [persistence.md](/docs/technical/persistence.md).
