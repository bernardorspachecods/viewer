---
description: "Current Viewer documentation: user-visible app behavior (one document per area) and technical architecture (one document per concern)."
---

# Viewer documentation

## Task routes

| Task | Start here |
| --- | --- |
| Change windows, tabs, or workspaces | [Workspaces and tabs](/docs/behavior/workspaces-and-tabs.md) |
| Change the sidebar tree or its search | [File tree](/docs/behavior/file-tree.md) |
| Change saving, conflicts, closing, or diffs | [Editing, saving, and diffs](/docs/behavior/editing-and-diff.md) |
| Change Markdown preview or editing | [Markdown](/docs/behavior/markdown.md) |
| Change LaTeX or PDF behavior | [LaTeX and PDF](/docs/behavior/latex-and-pdf.md) |
| Change JSON behavior | [JSON](/docs/behavior/json.md) |
| Change CSV behavior | [CSV](/docs/behavior/csv.md) |
| Change image or Word preview behavior | [Images and Word](/docs/behavior/images-and-word.md) |
| Change reply capture, reader windows, or snapshots | [Reply capture and snapshots](/docs/behavior/reply-capture-and-snapshots.md) |
| Change settings or what persists | [Settings and persistence](/docs/behavior/settings-and-persistence.md) |
| Change module boundaries or coordination | [Technical architecture](/docs/technical/architecture.md) |
| Change window composition or UI state | [UI architecture](/docs/technical/ui-architecture.md) |
| Change scanning, tree updates, or watchers | [Filesystem and watching](/docs/technical/filesystem-and-watching.md) |
| Change rendering or LaTeX compilation | [Rendering and compilation](/docs/technical/rendering.md) |
| Change stored state | [Persistence](/docs/technical/persistence.md) |
| Change security boundaries | [Security boundaries](/docs/technical/security.md) |
| Check what is verified and what is not | [Verification and known gaps](/docs/technical/verification.md) |

## Conventions

Before writing or revising a document here, follow [documentacao.md](/repo-library/modules/documentacao.md) in the repo library.

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
| User-visible CSV behavior: parsing, the spreadsheet-like grid, cell editing with Enter and Esc, saving that keeps the delimiter, and the limits on rows and columns. | [csv.md](/docs/behavior/csv.md) |
| Editing rules shared by Markdown, JSON, CSV, and LaTeX source: drafts, explicit saving, discarding, external conflicts, closing with unsaved changes, and diffs against disk or Git. | [editing-and-diff.md](/docs/behavior/editing-and-diff.md) |
| User-visible behavior of the workspace sidebar: the file tree, its filters and searches, file operations, and the performance limits that rule out drag and per-row hover. | [file-tree.md](/docs/behavior/file-tree.md) |
| User-visible behavior of the image previews (PNG, JPEG, WebP, HEIC/HEIF) and the Word (.docx) preview: read-only display, fit and zoom, refresh, and search. | [images-and-word.md](/docs/behavior/images-and-word.md) |
| User-visible JSON behavior: the validated raw preview, the raw editor that saves only valid JSON, the diff against disk or Git, and what happens to invalid drafts. | [json.md](/docs/behavior/json.md) |
| User-visible LaTeX and PDF behavior: root selection, compilation and its errors, the split view with debounced recompilation, SyncTeX jumps including bibliography entries, and the limits of each. | [latex-and-pdf.md](/docs/behavior/latex-and-pdf.md) |
| User-visible Markdown behavior: the rendered preview, links between files, Quick Edit, the source editor with its list and completion rules, split view, and the limits of math and of Quick Edit. | [markdown.md](/docs/behavior/markdown.md) |
| User-visible reply capture from terminal CLIs (⇧⌘E and ⌥⌘E), the standalone reader windows they open, snapshots of a preview selection, and the Accessibility and quit behavior that affects the global shortcut. | [reply-capture-and-snapshots.md](/docs/behavior/reply-capture-and-snapshots.md) |
| User-visible settings (theme, zoom defaults, shell escape, default workspace folders, file types) and what the app keeps or drops across restarts. | [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md) |
| Search, zoom, outline, and reading position as they behave across previews and editors: one search bar, per-document zoom and reading position, and the saved outline layout. | [view-controls.md](/docs/behavior/view-controls.md) |
| User-visible rules for workspaces (one native window tab per folder), the window header, document tabs, opening and closing, and what is restored at launch. | [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md) |
| Technical architecture of the Swift code: the boundary between the Core and App targets, who coordinates state, and the rules that keep side effects out of views. | [architecture.md](/docs/technical/architecture.md) |
| How the app scans workspace folders lazily, filters the tree by file kind, and watches directories and open files so that the tree and previews update without autosaving edits. | [filesystem-and-watching.md](/docs/technical/filesystem-and-watching.md) |
| How app state is stored: the versioned Codable model in Core, the single UserDefaults access point, the keys that must not be renamed, and what is kept out of stored state. | [persistence.md](/docs/technical/persistence.md) |
| How documents become previews: the Markdown adapter and its image embedding, LaTeX compilation in temporary workspaces with its cache rules, image validation, render generations, and the known limits of compilation and SyncTeX. | [rendering.md](/docs/technical/rendering.md) |
| Security boundaries of the app: the Markdown web view's Content Security Policy and script settings, the rule that build output stays out of the user's folder, LaTeX path filtering, authorization of outside files, and the shell escape default. | [security.md](/docs/technical/security.md) |
| UI architecture of the macOS app: window composition, which layer presents overlays and snapshots, how the sidebar is rendered, and how the document surfaces are coupled to the models. | [ui-architecture.md](/docs/technical/ui-architecture.md) |
| How the Viewer code is verified today: the two executable runners that exercise Core, the single app test file, and the areas with no automated coverage that must be treated as known gaps. | [verification.md](/docs/technical/verification.md) |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->
