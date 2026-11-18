---
bkf: document
description: "User-visible CSV behavior: parsing, the spreadsheet-like grid, cell editing with Enter and Esc, saving that keeps the delimiter, and the limits on rows and columns."
tags: [behavior, csv]
---

# CSV

Shared saving, conflict, and undo rules are in
[editing-and-diff.md](/docs/behavior/editing-and-diff.md).

## Reading

- `.csv` files are read and shown as a table. Quoted fields, escaped quotes, and
  multiline rows are supported.
- The delimiter (comma, semicolon, or tab) is detected automatically.
- The grid shows column letters and row numbers, an active cell, and keyboard
  navigation.
- The preview supports search, zoom, snapshots, and automatic updates when the file
  changes.

## Editing

- Double-clicking a cell edits it. Enter on a selected cell also starts editing it.
- While editing a cell, Enter or Esc confirms the value into the draft. The file is
  not saved by confirming a cell.
- Outside cell editing, Esc sends a save request for the file, as the CSV view's key
  handler does today.
  **Open question:** is saving on Esc intended? The earlier documentation described Esc
  only as confirming a cell.
- Undo and Redo are in the editing bar. `⌘Z` undoes and `⇧⌘Z` redoes draft changes
  without saving.
- `⌘S` saves. The saved file keeps the detected delimiter, and quotes a field only
  when needed.
- While a draft exists, an external change to the file shows a conflict with two
  options: keep the draft, or use the external version.
- Rows and columns cannot be created or removed.
