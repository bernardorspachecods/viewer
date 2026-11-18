---
bkf: document
description: "Editing rules shared by Markdown, JSON, CSV, and LaTeX source: drafts, explicit saving, discarding, external conflicts, closing with unsaved changes, and diffs against disk or Git."
tags: [behavior, editing, diff]
---

# Editing, saving, and diffs

This document owns the rules every editable format shares. Format-specific keys,
toolbars, and limits are in the format documents: [markdown.md](/docs/behavior/markdown.md),
[json.md](/docs/behavior/json.md), [csv.md](/docs/behavior/csv.md), and
[latex-and-pdf.md](/docs/behavior/latex-and-pdf.md).

## Drafts and saving

- Editing works on a draft. Nothing is saved automatically: autosave is not
  supported for any format.
- `Save` writes the draft to the file. When the document is saved, `Save` stays
  visible but disabled, and `Discard Changes` is hidden.
- `Discard Changes` restores the saved version and keeps the editor in its
  current mode.
- Undo and redo act on the draft only and never save.

## External changes and conflicts

- If the file changes on disk while a draft exists, the app opens a conflict
  instead of saving. The draft is never overwritten silently, and the external
  change is never saved automatically.
- Conflict resolution differs by format: Markdown and JSON show a conflict
  panel; CSV offers keeping the draft or using the external version.
- For LaTeX, a change to a dependency other than the edited source only triggers
  recompilation and keeps the draft.

## Closing with unsaved changes

- Closing a document tab with unsaved changes offers: continue editing, save, or
  discard.
- Closing a workspace tab with unsaved changes asks once: save all, discard all,
  or cancel.

## Diffs

- The diff toolbar opens a diff with two modes:
  - `Version saved on disk`: the draft against the file contents.
  - `Git diff`: the draft against `HEAD`.
- The left column is a read-only reference. The right column is the editor, and
  edits there keep updating the live preview where one exists. Both columns scroll
  together, so corresponding lines stay aligned.
- The diff keeps draft undo and redo. It does not keep a list of earlier versions.
- In Git diff mode, `Discard Git Changes` appears when the file is tracked and has
  a `HEAD` version. One confirmation restores the whole file to `HEAD`, discarding
  staged, unstaged, and draft changes. The editor stays open and returns to source
  mode.
- A file outside Git, or without a `HEAD` version, shows an explanatory state in
  Git diff mode. The disk comparison stays available.
- For LaTeX, diffs and Git discard apply to the contextual source file.
- Closing the diff restores the previous mode.

## Typing aids in raw editors

- The raw-text editors (Markdown source, JSON, LaTeX source) use macOS spell
  correction, system inline predictions, and native macOS completions.
- The JSON and LaTeX editors also keep quote, dash, and text substitutions
  disabled, so source text is not rewritten while typing.
- Markdown's dictionary-based word completion is described in
  [markdown.md](/docs/behavior/markdown.md).

## Not supported

- Autosave, for any format.
- Editing several files in one LaTeX session (see [latex-and-pdf.md](/docs/behavior/latex-and-pdf.md)).
