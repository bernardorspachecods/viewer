---
bkf: document
description: "User-visible Markdown behavior: the rendered preview, links between files, Quick Edit, the source editor with its list and completion rules, split view, and the limits of math and of Quick Edit."
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
| Editing directly in the preview | [Quick Edit](#quick-edit) |
| The source editor, its completions, and lists | [Source editor](#source-editor) |
| Limits you must not assume away | [Limits](#limits) |

## Preview and links

- The preview shows headings with an outline, lists, tables, code blocks, links,
  images, and common TeX mathematics rendered as MathML.
- Local images are shown in the preview and count as dependencies: a change to an
  image refreshes the preview.
- Links to Markdown and LaTeX files open or focus their tabs. Links to other local
  files open in the macOS default app. External links open in the browser.
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
  HTML is never emitted as markup; it shows the grey "HTML raw" placeholder, with
  the source of a block shown as plain text.
- A bare `<b>` with no closing tag stays bold to the end of its paragraph.
- If an update fails, the preview keeps the last good result and shows the
  diagnostic.

- Selected text is copied on select; see [view-controls.md](/docs/behavior/view-controls.md#selection).

## Quick Edit

- Double-clicking anywhere in the preview starts Quick Edit. The caret goes to the
  paragraph, heading, or list item under the pointer when that unit is editable;
  otherwise Quick Edit starts without a caret.
- Typing updates the draft without reloading the preview. `Save` and `Esc` save
  and leave editing, as in the source editor. Quick Edit does not autosave.
- Inline markup such as bold and links is kept where the Markdown source can be
  mapped safely. An edit that cannot be mapped is rejected, and the preview
  re-renders from the draft, which drops that change.
- Editable as text: paragraphs, headings, and list items.
- Read-only as a whole: a paragraph, heading, or list that contains an image,
  display math, or `<`; thematic breaks; and front matter.
- Code blocks, tables, and quotes accept typing, but every edit to them is
  rejected, so the text reverts.
- A typed change is committed to the draft 120 ms after typing stops. A change
  typed in the moment before `Save` or `Esc` can miss the draft, because a change
  that arrives after editing has ended is ignored.

## Source editor

- The `Raw Markdown` toolbar button switches between Quick Edit and the source
  editor and keeps the draft. The button is hidden in split view and while a diff
  is open.
- The source editor has syntax highlighting for light and dark themes, undo and
  redo, `⌘B`, `⌘I`, and `⌘K`, and the shared saving, conflict, and discard rules.
- Spell correction is on. For inline word completion, the editor uses the
  on-device Apple Foundation model when it is available for the current language.
  Otherwise, for languages without native macOS inline predictions, it suggests
  words from the local dictionary. The suggestion appears in gray: `Space` accepts
  the word and a following space, `Tab` accepts only the word. For languages with
  native predictions, macOS provides them.
- In lists with `-`, `*`, or `+` markers, Return continues the list. In ordered
  lists with `.` or `)`, Return increments the number. Return on an empty list line
  removes the marker and ends the list.
- The source editor can fill the whole area or use split view: source on the left,
  live preview on the right.

## Limits

- Math is limited to the common TeX surface the renderer handles. Arbitrary TeX
  math commands, packages, macros, environments, alignment, labels and references,
  and custom commands are not validated. Rendering details are in
  [rendering.md](/docs/technical/rendering.md).
- The Quick Edit commit delay can drop a change typed just before `Save` or `Esc`
  (see above).
