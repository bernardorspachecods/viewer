---
bkf: document
description: "User-visible behavior of the workspace sidebar: the file tree, its filters and searches, file operations, and the performance limits that rule out drag and per-row hover."
tags: [behavior, sidebar, file-tree]
---

# File tree

## Showing files

- The sidebar shows the workspace folder as the root and a tree of its folders and
  files. Hidden files are ignored unless "Show hidden files" is on in the sidebar
  options menu. It is off by default and saved per workspace.
- The tree loads the first level and expands folders on demand. Expansion,
  scroll position, and filter state are kept per workspace.
- "Show selected files only" is on by default, in the sidebar options menu. When
  it is on, only files whose type is checked in Settings > Files are shown; a
  folder stays when it contains a shown file. Turning it off shows all files.
- Selecting a file opens or focuses its tab when the app supports its type. Other
  files open in the macOS default app.
- The supported types are defined in the code under `Sources/BPViewerCore/`. Each
  type's behavior is in its own document (see the [documentation map](/docs/MAP.md)).

## Search

- Name or path search looks only at folders directly inside the root. It scrolls
  to the first match and highlights it. It does not filter the tree and does not
  search descendants.
- Search, and turning off "Show selected files only", may need a full index of
  the workspace. The sidebar shows the indexing state while it runs.

## Collapsing

- The sidebar header collapses all folders and clears their expansion records.
- On hover, each first-level folder shows the same action for its own branch only.

## File operations

- Folder context menu: copy path, rename, move to Trash.
- File context menu: rename, duplicate, move to Trash.
- Open tabs follow renames.
- An item with unsaved changes cannot be moved to the Trash.

## Constraints

- Tree rows cannot be dragged. Per-row drag support made scrolling slow in large
  trees with hidden files shown. Per-row hover is limited to expanded top-level
  folders for the same reason. Tab reordering is separate; see
  [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- Limits of the tree on very large or unusual folders (permission-denied
  directories, symlinks, concurrent renames) are not covered by automated checks;
  see [verification.md](/docs/technical/verification.md).
