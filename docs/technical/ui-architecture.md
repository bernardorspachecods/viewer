---
bkf: document
description: "UI architecture of the macOS app: window composition, which layer presents overlays and snapshots, how the sidebar is rendered, and how the document surfaces are coupled to the models."
tags: [architecture, ui]
---

# UI architecture

Behavior that users see is in the behavior documents routed from
[the documentation map](/docs/MAP.md). This document covers the structure
that produces it. Module boundaries and coordination are in
[architecture.md](/docs/technical/architecture.md).

## Window composition

- Each workspace window has one header bar spanning the window, above the sidebar
  column and the document column. The header is a single row and never wraps.
  Its content rules are in [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- The document column holds the tab bar and one surface per document kind. Preview
  and editor views are chosen by document kind; the views live in `Sources/BPViewerApp/`.
- Overlays (outline, diff, settings, errors, root selection, permissions, and
  workspace switching) are presented by the app layer, not by the preview views.
- Snapshots use a separate AppKit window.
- Reader windows omit the sidebar toggle, the folder button, and the workspace
  identity. Their rules are in [reply-capture-and-snapshots.md](/docs/behavior/reply-capture-and-snapshots.md).

## State

- `WorkspaceWindowManager` creates the windows as native tabs, restores their order,
  and routes global commands to the active window. Each model's window presentation
  (`WindowPresentation`: workspace, standalone, or reader) is set once, at creation.
- `AppModel` is the observable object for one workspace. It publishes the state the
  surfaces render; the published properties are in `Sources/BPViewerApp/AppModel.swift`.
- Render, edit, and diff requests go to their coordinators. The results come back as
  events that `AppModel` applies.
- Settings changes also go through `AppModel`.

## Sidebar

- Expanded branches are flattened into a list of visible rows before `LazyVStack`
  renders them. Scrolling never builds one recursive view holding every descendant.
- Tree rows have no drag and drop, and per-row hover is limited to expanded
  top-level folders. The reason is in [file-tree.md](/docs/behavior/file-tree.md).

## Surfaces and coupling

- Markdown: Quick Edit changes are sent to `AppModel` and applied to the Markdown
  source in Core, not in the view. The shared search bar sits on the tab surface and
  follows focus between editor and preview in split view.
- Raw editing and diff: Markdown source, JSON, and the diff use one shared AppKit
  editor, which draws the line gutter and the Git-style decorations. The diff uses
  one view for Markdown and JSON. Both sides use the same per-line height map, so
  corresponding lines stay aligned while either side scrolls.
- LaTeX: a PDF double-click is resolved to a source location in the app. A
  bibliography jump reads the saved `.bbl` file, not the draft.
- PDF: local links go to the app's router; external links go to the browser.
- Images and Word: image reads go through the render coordinator (see
  [rendering.md](/docs/technical/rendering.md)).
- Terminal reply capture is a separate engine in `Sources/BPViewerApp/TerminalReader/`;
  see [terminal-reader.md](/docs/technical/terminal-reader.md).
