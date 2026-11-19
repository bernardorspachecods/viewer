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
  it is on, only files whose type is checked in Settings > Files, or whose extension
  was added there under "Other types", are shown; a
  folder stays when it contains a shown file. Turning it off shows all files.
- Selecting a file opens or focuses its tab when the app supports its type. Other
  files open in the macOS default app.
- The supported types are defined in the code under `Sources/ViewerCore/`. Each
  type's behavior is in its own document (see the [documentation map](/docs/MAP.md)).

## Search

- Name or path search looks only at folders directly inside the root. It scrolls
  to the first match and highlights it. It does not filter the tree and does not
  search descendants.
- Search, and turning off "Show selected files only", may need a full index of
  the workspace. The sidebar shows the indexing state while it runs.

## Collapsing

- The workspace root has a chevron in the sidebar header. It hides or shows the
  whole listing under the root. A press takes one step:
  - If the listing is hidden, the press shows it again (chevron down).
  - If the listing is shown and a folder inside it is open, the press closes every
    open folder and keeps the listing shown.
  - Otherwise the press hides the listing, and the chevron then points down.
- The root button is shown while the listing is hidden, and while the listing has
  subfolders. Revealing a file in the sidebar shows the listing first.
- A folder with at least one subfolder has a collapse button while it is open.
  The button is hidden until the pointer enters a bounded area around it (the
  button, 72 pt wide and one row tall), not the whole row. A press takes one step:
  - If an open folder sits inside it, the press closes every folder inside it and
    keeps the folder open.
  - Otherwise the press closes the folder itself with its branch.
- Folders without subfolders have no button. The expansion saved for the workspace
  is the expansion shown after each press.

## File operations

- Folder context menu: copy path, reveal in Finder, rename, move to Trash.
- File context menu: copy path, reveal in Finder, reload, rename, duplicate, move
  to Trash.
- Reveal in Finder opens Finder with the item selected in its folder. It does not
  change the sidebar.
- Open tabs follow renames.
- An item with unsaved changes cannot be moved to the Trash.

## Constraints

- Tree rows cannot be dragged. Per-row drag support made scrolling slow in large
  trees with hidden files shown. Hover is tracked only on the collapse button's
  slot (the 72 pt area around it), of open folders that have subfolders; no other row is tracked, and
  the folder row itself is not. Tab reordering is separate; see
  [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- Limits of the tree on very large or unusual folders (permission-denied
  directories, symlinks, concurrent renames) are not covered by automated checks;
  see [verification.md](/docs/technical/verification.md).
