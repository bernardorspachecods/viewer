---
bkf: document
description: "Search, zoom, outline, and reading position as they behave across previews and editors: one search bar, per-document zoom and reading position, and the saved outline layout."
tags: [behavior, search, zoom]
---

# Search, zoom, outline, and reading position

## Search

- `⌘F` opens one search bar for previews and source editors.
- Search covers only the active tab. It ignores case and accents. Enter moves to
  the next match and Shift+Enter to the previous one. Esc closes the bar.
- In split view, search applies to the panel that has focus.
- The PDF and Word previews send queries to their own engines; CSV, JSON (preview
  and editor), Markdown, and the other previews use the same bar.

## Zoom

- Each document has its own zoom, saved with its state. Default zoom levels are
  set in Settings; see [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md).
- Captured replies open at the default Markdown zoom; see
  [reply-capture-and-snapshots.md](/docs/behavior/reply-capture-and-snapshots.md).

## Selection

- With "Copy on select" on (the default, in Settings > Zoom), text selected with the
  mouse in a preview is copied to the clipboard when the mouse button is released.
  A double or triple click counts. A click without a selection does not touch the
  clipboard. Settings are in [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md).
- It applies to preview text only: Markdown, CSV, and LaTeX/PDF pages. Source editors
  and editable cells never copy on select, so editing does not replace the clipboard.
- Known gaps: the JSON preview is a read-only source view, so it does not copy on
  select; Word previews do not either, because their web view runs no scripts. A drag
  that ends outside the Markdown or CSV web view is not copied.

## Outline

- Markdown shows an outline of its headings, and PDF shows the document outline.
- The Markdown outline can be resized and shown or hidden. Its width and
  visibility are saved per file.

## Reading position

- The reading position is saved per document and restored when the document is
  opened again. PDF restores its reading position the same way.
