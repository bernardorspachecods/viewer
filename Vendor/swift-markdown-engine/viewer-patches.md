---
bkf: document
description: "Why the swift-markdown-engine source is vendored in this repository, the upstream revision it started from, and every local change to it."
tags: [vendor, markdown-editor]
---

# Vendored swift-markdown-engine

Upstream: https://github.com/nodes-app/swift-markdown-engine (Apache-2.0, see `LICENSE`),
copied at revision `ca0d9798b0e18a590840b366295f5a686c9c3daf`. Demo, media and docs were not copied.

It is vendored because the engine fixes some looks in code (table geometry, front matter) that the
preview and the editor must share through `MarkdownStyleTokens`. Every local change is marked in the
source with `VIEWER PATCH` and listed here, so a newer upstream revision can be merged by re-applying them.

## Local changes

- Tables take their geometry and colors from a new public `TableStyle` group on `MarkdownEditorConfiguration.table` (`MarkdownEditorConfiguration.swift`, `MarkdownStyler+Tables.swift`): cell padding, border width and color, header fill, and `fillsAvailableWidth` (equal column widths filling the container, like CSS `table-layout: fixed`, falling back to content-sized columns when the column minimums do not fit). The defaults reproduce the previous hard-coded look, and the table image cache key includes the style.
- YAML front matter can be drawn as the preview's card, through a new public `FrontMatterStyle` group on `MarkdownEditorConfiguration.frontMatter` (off by default, so the engine is unchanged unless the app enables it). Detection (`Parser/FrontMatter.swift`) follows Core's scanner: line 1 is `---` and a later line is `---` or `...`. When enabled, `MarkdownASTStyler+FrontMatter.swift` drops the blocks inside the region (the `---` lines are not thematic breaks, `# x` is no heading), styles each line (font scale, line height, indents, key semibold before the first `:`), and makes the two fence lines the card's top and bottom padding: hidden like code fences, as high as the padding (shifted by half the text line's leading so the text is centered), revealed muted while the caret is on them. `MarkdownTextLayoutFragment+FrontMatter.swift` paints each line's slice of one rounded rectangle across the text column (`.frontMatterCard` attribute; `fragmentNSRange` and `textStorage` of `MarkdownTextLayoutFragment` became internal for it). The coordinator restyles the whole card when an edit changes its shape and when the caret moves on or off a fence line (`NativeTextViewCoordinator+FrontMatter.swift`).
- `TableStyle.lineHeight`: table cell text can use a taller line than the font's natural one (`MarkdownStyler+Tables.swift`, `MarkdownEditorConfiguration.swift`); the extra is split above and below the text, as in CSS.
- `NativeTextView+ForwardMove.swift`: → never moves the caret backwards or not at all in left-to-right text; with a rendered inline formula followed by a space the caret used to bounce between the two positions after the formula.
