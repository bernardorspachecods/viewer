---
bkf: document
description: "How the app scans workspace folders lazily, filters the tree by file kind, and watches directories and open files so that the tree and previews update without autosaving edits."
tags: [architecture, filesystem, watchers]
---

# Filesystem and watching

## Scanning

- The tree is scanned lazily: the top level first, and children when a folder is
  expanded. Scanning code is in `Sources/ViewerCore/` (filesystem foundation).
- Filtering by file kind is per file. A folder is shown when it contains a shown
  file. Hidden files are skipped unless the workspace's hidden-files state is on.
- Search and the selected-files filter may need a full index of the workspace.
  That index is the cost behind the sidebar's indexing state.

## Watching

- Directory watchers update the tree.
- Watchers on the active file and its dependencies invalidate its preview.
- While a draft is being edited, an external change is handled as a conflict. It
  never triggers an autosave.
- Watchers on dependencies outside the workspace root are added only after the user
  authorizes those paths; see [security.md](/docs/technical/security.md).

## Limits

- Permission-denied directories, the symlink policy, concurrent renames, and large
  filesystem performance have no automated coverage; see
  [verification.md](/docs/technical/verification.md).
