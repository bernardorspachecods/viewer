---
bkf: document
description: "User-visible JSON behavior: the validated raw preview, the raw editor that saves only valid JSON, the diff against disk or Git, and what happens to invalid drafts."
tags: [behavior, json]
---

# JSON

Shared editing, conflict, and diff rules are in
[editing-and-diff.md](/docs/behavior/editing-and-diff.md).

## Preview

- `.json` files are validated and shown in a monospaced, read-only raw view. The
  view keeps the file's exact lines, including empty ones, with line numbers.
- The text can be selected and copied. The preview supports zoom, snapshots, and
  automatic updates when the file changes.
- Invalid JSON keeps the last valid preview, if there is one, and shows the
  validation diagnostic.

## Editor

- Double-clicking opens a monospaced raw editor with undo and redo. It has no split
  view.
- Saving is explicit and allowed only for valid JSON. An invalid draft can stay open
  and shows the `Unsaved` state; it is not saved until it is valid again.
- Discard Changes restores the saved version without leaving edit mode.
- Leaving the editor with invalid content asks whether to continue editing or
  discard. The save option appears only for valid JSON.
- The preview and the editor use the shared search bar.

## Diff

- The editor offers `Version saved on disk` and `Git diff`. The reference version is
  on the left and the editable raw editor is on the right, both with line numbers.
- Added lines on the right have a `+` marker and a green highlight, as in a Git diff.
- A file outside Git, or without a `HEAD` version, shows an explanatory state in
  Git mode, with disk comparison still available.
- `Discard Git Changes` works as described in
  [editing-and-diff.md](/docs/behavior/editing-and-diff.md).
