---
bkf: document
description: "Security boundaries of the app: the Markdown web view's Content Security Policy and script settings, the rule that build output stays out of the user's folder, LaTeX path filtering, authorization of outside files, and the shell escape default."
tags: [architecture, security]
---

# Security boundaries

- Markdown preview HTML is served under a local Content Security Policy.
- Content JavaScript is enabled in the Markdown preview web view, which runs Quick
  Edit and in-preview navigation. It is disabled in the Word preview web view. A
  change that adds script to either one needs a security review.
- **Open question:** the earlier architecture note said Markdown HTML does not enable
  content scripts, which contradicts the code (`MarkdownWebPreview.swift`, `MarkdownEditingJavaScript.swift`). Confirm that
  content JavaScript in the Markdown preview is intended.
- The app does not write build artifacts into the user's source folder. LaTeX
  compiles in a temporary workspace.
- LaTeX dependency paths are resolved and filtered before compilation.
- A dependency outside the project root needs explicit approval. Once approved, it is
  watched.
- `shell escape` is disabled by default. It changes only through the explicit
  setting described in [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md).
