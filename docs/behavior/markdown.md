---
bkf: document
description: "User-visible Markdown behavior: the rendered preview, links between files, the Markdown editor with its live styling, and the limits of math and of the editor."
tags: [behavior, markdown]
---

# Markdown

Shared editing rules (drafts, saving, conflicts, diffs) are in
[editing-and-diff.md](/docs/behavior/editing-and-diff.md). Search and zoom are in
[view-controls.md](/docs/behavior/view-controls.md).

## Navigation map

| If you need... | Section |
| --- | --- |
| What the preview shows and how links behave | [Preview and links](#preview-and-links) |
| Editing, shortcuts, and what the editor does not do | [Markdown editor](#markdown-editor) |
| Limits you must not assume away | [Limits](#limits) |

## Preview and links

- The preview shows headings with an outline, lists, tables, code blocks, links,
  images, and common TeX mathematics rendered as MathML.
- Local images are shown in the preview and count as dependencies: a change to an
  image refreshes the preview.
- Links to Markdown and LaTeX files open or focus their tabs. Links to other local
  files open in the macOS default app. External links open in the browser.
- A link starting with `/` (`/MAP.md`, `/docs/a.md`) is read from the project root,
  as repositories write it: the nearest folder above the document with a `.git`
  entry, or else the nearest folder above the document that holds the path. A path that exists on the disk is kept as written. When no file matches, the
  click does nothing and shows no message.
- Relative links (`./a.md`, `../b.md`) resolve from the document's folder. A
  destination may be percent-encoded (`my%20notes.md`) or written in angle brackets
  with spaces (`<my notes.md>`).
- A link with a fragment scrolls to that heading. In the same document it scrolls
  in place; into another Markdown or LaTeX file it opens the file and scrolls there.
- Fragments match a heading id exactly first, then by its normalized form: lower
  case, accents folded, every other run of characters becomes `-`. So `#seção` and
  `#secao` both find "Seção", and `#1-introdução` finds "1. Introdução". Repeated
  headings get `-2`, `-3`, and so on. An accent that is folded to a different
  letter (`ç` to `c`) changes the key: "Secção" is `seccao`.
- Raw HTML in the preview is not run. A line break (`<br>`, `<br/>`, `<br />`) and
  the formatting tags `b`, `strong`, `i`, `em`, `u`, `sub`, `sup`, `kbd`, `mark`,
  `code`, `s`, `del`, `small` render when written bare (no attributes). Any other
  HTML is never emitted as markup; it shows a quiet grey placeholder labelled `HTML`
  (none for a comment, which shows only its text), with
  the source of a block shown as plain text.
- Front matter made only of flat `key: value` lines shows as a small property list
  above the document. Lists, nested keys, and block scalars keep the text block
  labelled `Front matter`.
- By default the text of the preview and of the editor runs to the window edges, with
  a side padding that shrinks with the window (from 64 px down to 20 px; 56 px inset in
  the editor). Settings > Appearance > Markdown Text Width keeps it in a centered
  column instead (860 px in the preview, 760 px in the editor). The setting applies to
  every window at once.
- A bare `<b>` with no closing tag stays bold to the end of its paragraph.
- If an update fails, the preview keeps the last good result and shows the
  diagnostic.

- Selected text is copied on select; see [view-controls.md](/docs/behavior/view-controls.md#selection).

## Markdown editor

- The preview is read-only. Double-clicking it does nothing. Editing starts only
  with the `Markdown Editor` toolbar button, and the editor replaces the preview.
  The button is hidden while a diff is open.
- Clicking the button again, `Esc`, and `Save` all leave editing and save the draft,
  as every editable format does (see
  [editing-and-diff.md](/docs/behavior/editing-and-diff.md)).
- The editor styles the Markdown while you type (headings, emphasis, lists, quotes,
  tables, task checkboxes, code with syntax highlighting, and TeX math), but the text
  it edits is the Markdown source itself. Its text width follows the Markdown Text Width setting.
- The editor and the rendered preview share one style definition, so the same Markdown
  looks the same in both: typography, headings, links, lists, task boxes, quotes, tables,
  code colors, and inline comments (shown as a muted chip with only the note text). What
  cannot match is listed in [rendering.md](/docs/technical/rendering.md).
- Fenced code without a language (or tagged `text`, `txt`, `plain`, `plaintext` or `none`) is
  not colored, because guessing a language colored ordinary words as keywords.
- Switching between the preview and the editor, in either direction, keeps the same text at
  the same height, and the new view appears already scrolled there (no frame at the top of the
  document). Positions near the end of a document are clamped to what the other view can
  scroll to; other known differences are in [rendering.md](/docs/technical/rendering.md).
- Undo and redo replace the whole draft and put the caret at the end of the text they changed,
  so you keep typing inside the table cell, list item or style you were in.
- Undo and redo act on the draft, `⌘B`, `⌘I`, and `⌘K` apply bold, italic, and inline
  code, and Return continues or ends a list.
- Spell correction is on. The app's own inline word completion (Apple Foundation
  model and local dictionary) is not part of this editor.
- Picking a heading in the outline while editing moves the caret to it.
- The editor fills the whole pane. Showing two files side by side is Split View, which is
  between tabs (see [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md#split-view)).
- The engine is the third-party `swift-markdown-engine`, pinned to one revision (see
  [ui-architecture.md](/docs/technical/ui-architecture.md)).

## Limits

- Math is limited to the common TeX surface the renderer handles. Arbitrary TeX
  math commands, packages, macros, environments, alignment, labels and references,
  and custom commands are not validated. Rendering details are in
  [rendering.md](/docs/technical/rendering.md).
- The diffs keep the raw source editor, not the Markdown editor: its syntax
  highlighting, line gutter, and word completion are described in
  [editing-and-diff.md](/docs/behavior/editing-and-diff.md).
