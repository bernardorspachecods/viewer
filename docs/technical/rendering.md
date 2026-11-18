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
