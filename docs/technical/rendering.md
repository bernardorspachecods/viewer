---
bkf: document
description: "How documents become previews: the Markdown adapter and its image embedding, LaTeX compilation in temporary workspaces with its cache rules, image validation, render generations, and the known limits of compilation and SyncTeX."
tags: [architecture, rendering, latex, markdown]
---

# Rendering and compilation

## Markdown

- Link destinations and heading anchors are resolved in Core by
  `MarkdownLinkResolver` and `MarkdownAnchor`, which the renderer and the app share.
  The web view only cancels same-document fragment navigation and scrolls in place;
  cross-file fragments travel in the bridge URL and the tab's anchor request.
- Raw HTML passes only through the allowlist in `MarkdownSafeInlineHTML`; everything
  else becomes the placeholder.
- `SwiftMarkdownAdapter` in Core uses swift-markdown to produce HTML. The adapter
  escapes text and attributes, controls URL schemes, collects dependencies, and
  builds the outline and the editable blocks.
- Local images are embedded as `data:` URLs. WebKit did not reliably load relative
  local resources from the in-memory HTML that `WKWebView.loadHTMLString` uses.
  The image file paths stay in the dependency list, so the watcher still observes
  them.
- Math is rendered by Core's MathML renderer. Its coverage is the subset that renderer
  implements; the user-visible limit is in [markdown.md](/docs/behavior/markdown.md).

## Shared Markdown style

- `MarkdownStyleTokens` in Core is the one definition of how Markdown looks. The
  preview's CSS is generated from it by `MarkdownStylesheet`, and the editor reads the
  same tokens, so a value changed there changes both.
- Values the engine fixes and does not expose (table geometry, blockquote bar and indent,
  list marker glyph) are copied into the tokens, so the preview can match them. Do not
  add CSS literals that duplicate a token.
- The editor spaces blocks with the blank source line between them, so the preview's gap
  between blocks is one line height (`blockSpacingEm`), headings add the engine's extra top
  spacing as padding (margins would collapse), and the engine's `spacingFactor` is 0.
- Table geometry (cell padding, border width and color, header fill, full width with equal
  columns) is shared through the tokens; the editor reads it through the vendored engine's
  `TableStyle` (`viewer-patches.md`).
- Front matter is the same card in both views (padding, radius, background, font size, line
  height, row gap, key weight and color are `frontMatter*` tokens). The editor draws it through
  the vendored engine's `FrontMatterStyle` patch, keeping the YAML editable as raw
  `key: value` lines; the blank source line after the card is the gap after it
  (`frontMatterBottomSpacing` is 0).
- The editor is configured at one zoom: `MarkdownStyleTokens.scaled(by:)` scales every size
  in points, and a changed zoom rebuilds the editor. The preview zooms the whole page.
- Known gap: the preview's CSS is generated per render from the shared tokens; a token
  change takes effect on the next render, not in a page already open.
- Known gaps where the two cannot look the same, because the editor shows source: raw
  HTML tags (`<kbd>`, `<mark>`, ...) show as text in the editor; the preview's front matter
  card lines its values up in a column and the editor's shows `key: value` source; a single newline inside a paragraph
  is a line break in the editor and a space in the preview; a fenced code block shows its
  two fence lines as empty lines in the editor, which the preview mimics with padding.
- Small measured residuals remain (about 1-3 points of vertical offset after headings,
  table width, engine-fixed sizes such as table padding that do not scale with zoom, and the
  comment chip font, which does not follow zoom).
- Switching between preview and editor keeps the reading position. `MarkdownReadingPosition`
  carries `sourceOffset` (UTF-8 start of the block at the top of the view; the renderer writes it
  as `data-bp-source-offset` on each block) and `blockTop` (that block's top edge below the top
  of the view, CSS px at zoom 1). The page reports it on every scroll through a message handler,
  so it is current even as the web view is torn down; the editor reports it, debounced, from its
  TextKit layout (`MarkdownLiveEditorViewport`) and restores it in timed passes because tables
  and formulas settle their height after the text appears. `MarkdownLiveEditorStyle.textDrop`
  is how much lower the editor draws a block's text than CSS (0 for tables). The caret enters
  at the first on-screen paragraph, so no syntax is revealed. Positions saved before these
  fields existed decode with `blockTop` 0.
- The incoming surface is hidden until the position is applied: the editor has opacity 0 until
  `onEntryApplied`, and a new web view has `alphaValue` 0 until `didFinish` has run the scroll.
  Without that, each showed the top of the document for a frame. One blank frame can still show
  between the two. A reload of a page already on screen is not hidden.
- Known gaps in the position match, measured (not exact): about 0-1 pt for paragraphs, lists
  and headings; 2-15 pt around code blocks, horizontal rules and display formulas
  (`codeSpaceAfter`, `ruleSpaceAfter`, `mathSpaceBefore` are tuned by measurement); the editor
  does not render local images (it shows `![..](..)`), so a document with images is shorter
  there; positions near the end of a document are clamped.
- Preview code blocks are colored by the same highlight.js bridge and GitHub theme as the
  editor, reached through the Core protocol `MarkdownCodeHighlighting`; the app supplies
  `MarkdownPreviewCodeHighlighter`.
- Each colored run carries both appearances as `light-dark(light, dark)`, so the preview
  follows the system appearance without re-rendering.

## LaTeX

- `LocalLatexAdapter` resolves the root and prepares a temporary workspace. When a
  contextual draft exists, it uses an overlay on that workspace instead.
- The compiler runs through `ProcessRunner`. The adapter then collects dependencies,
  validates the generated PDF, and returns SyncTeX data when it is available.
- The render cache is keyed by root, dependencies, compiler, and configuration.
  Draft previews are not cached.
- Known limits:
  - `ProcessRunner` checks cancellation and sends termination signals, but long
    compilations may still need more reliable process cancellation.
  - Draft overlays must handle complex relative paths, `\input`, `\include`,
    `\graphicspath`, and bibliographies correctly.
  - Some engines or distributions do not provide SyncTeX, or produce incomplete
    maps.
  - Large projects and external dependencies make live preview expensive.

## Images

- A supported image is read as bytes and validated with ImageIO before it reaches the
  native surface. The original file is not changed.
- A change to the active image triggers a new read through `DocumentRenderCoordinator`.

## Generations

- Each render carries a generation. A cancelled or obsolete result never replaces the
  tab's latest state.
