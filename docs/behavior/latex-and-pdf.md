---
bkf: document
description: "User-visible LaTeX and PDF behavior: root selection, compilation and its errors, the split view with debounced recompilation, SyncTeX jumps including bibliography entries, and the limits of each."
tags: [behavior, latex, pdf]
---

# LaTeX and PDF

Shared editing rules are in [editing-and-diff.md](/docs/behavior/editing-and-diff.md).
Authorization of files outside the project is in
[security.md](/docs/technical/security.md).

## Navigation map

| If you need... | Section |
| --- | --- |
| Which file is compiled | [Roots](#roots) |
| Compilation, errors, and split view | [Compiling and split view](#compiling-and-split-view) |
| Jumping between PDF and source | [SyncTeX and bibliography](#synctex-and-bibliography) |
| PDF viewing | [PDF](#pdf) |
| Known limits | [Limits](#limits) |

## Roots

- Existing PDF files open directly in tabs, on the same PDF surface the LaTeX
  preview uses.
- When a LaTeX file is opened, the app looks for roots inside the workspace. A
  single root is selected automatically. Zero or several roots open a picker.
- The root selection is saved per workspace. An opened chapter stays the context of
  the root's tab instead of opening a second preview tab.

## Compiling and split view

- The compiler is `latexmk` when it is available. Otherwise `pdflatex`, `xelatex`,
  or `lualatex` is used, depending on the installation and the document.
- Compilation runs in a temporary workspace and produces the PDF shown in the
  preview. The project folder is not written.
- Dependencies outside the workspace need your authorization. The `shell escape`
  mode is a setting (see [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md)).
- Compilation errors are shown. You can expand and copy the diagnostic. When a
  compilation fails, the previous PDF stays visible.
- Split view keeps the edited source on the left and the PDF on the right. Changes
  compile after a two-second debounce. Errors keep the last valid PDF.
- Contextual source can be saved independently of the compilation result.
- Toolbar: source or split view, Undo, Redo, Save, Discard Changes, Disk Diff, and
  Git Diff.

## SyncTeX and bibliography

- Double-clicking a LaTeX PDF opens the contextual source, or the root, at the
  matching line with line numbers, and tries to place the cursor through SyncTeX.
  Without a usable map, it opens the editor without moving the cursor.
- A `.bib` file opened from the tree uses the project's LaTeX root and opens as
  contextual source in the same editor.
- A citation can open its entry directly in the references file.
- Double-clicking a printed reference in the PDF opens that entry in the `.bib`
  file, through the generated `.bbl` map. Double-clicking the bibliography title
  opens the start of the `.bib` file.

## PDF

- The PDF supports an outline, search, copy, printing, zoom, and reading position
  restoration. Local links are handled in the app; external links open in the
  browser.
- Right arrow shows the next page and Left arrow the previous one. Each step puts the
  top of that page at the top of the view. Arrows at the first or last page do
  nothing.
- The PDF takes the keyboard when it opens and when it is clicked, so the arrows work
  without a first click. While a text field or the find field is editing, the arrows
  go to that field instead. Arrows with ⌘, ⌥, ⌃, or ⇧ are not page steps.
- The arrows work in focus mode too (see [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md)).

## Limits

- Editing several files in one LaTeX session is not supported.
- Compilation on every keystroke is not supported; recompilation is always
  debounced.
- Engines and distributions may not provide SyncTeX, or may produce incomplete
  maps. Then double-clicks cannot place the cursor. Details are in
  [rendering.md](/docs/technical/rendering.md).
- Large projects and external dependencies make live preview expensive.
