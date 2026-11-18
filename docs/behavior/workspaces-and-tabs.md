---
bkf: document
description: "User-visible rules for workspaces (one native window tab per folder), the window header, document tabs, opening and closing, and what is restored at launch."
tags: [behavior, workspaces, tabs]
---

# Workspaces and tabs

## Workspaces

- A workspace is one local folder, shown as a native macOS window tab with its
  own header, sidebar, file tree, and document tab bar.
- The folder button, the native `+`, and `⇧⌘T` open a folder through the folder
  picker in a new workspace tab. A folder that is already open is focused, not
  opened a second time.
- Switching workspaces does not close tabs or ask for confirmation.
- Closing a workspace tab with unsaved changes asks once: save all, discard all,
  or cancel.
- Files opened from Finder or dropped on the app are routed by the app. Markdown
  opened from Finder appears in a reader window; see
  [reply-capture-and-snapshots.md](/docs/behavior/reply-capture-and-snapshots.md).

## Header bar

- One row above the sidebar and the document area. In a workspace window it
  shows the sidebar toggle, the folder button, the workspace name and path (copy
  on hover), then the active document's title and path.
- Long paths truncate in the middle. The document title keeps priority over the
  path; the workspace path truncates first.
- An untitled tab shows `Not saved`.
- On the right: the `Updated` time (refresh on hover), the status badge, the
  LaTeX root and settings controls, snapshot capture, zoom, and the theme toggle.
  A control appears only when the active document supports it.

## Document tabs

- Each file has at most one tab. Tabs can be selected, reordered by dragging,
  closed one at a time, closed to the right, or closed except the selected tab.
- `⌘W` closes the active document tab in the key window. When the window has no
  document tabs left, `⌘W` closes the workspace window instead, including when it
  is the only workspace window. The unsaved-changes rules in
  [editing-and-diff.md](/docs/behavior/editing-and-diff.md) still apply. The app
  keeps running after its last window closes.
- The `+` button at the end of the tab bar creates an in-memory Markdown tab with
  no path. The first `Save` opens a panel to choose the `.md` file. Such a tab is
  not restored after a restart.

## Launch and restore

- At launch the app restores every existing workspace tab in its previous order
  and focuses the last active one. References to folders or tabs that no longer
  exist are removed.
- If nothing can be restored, the app opens the default workspace folders set in
  Settings > Workspaces: the first in the initial window, the rest as native tabs
  in list order. The home folder opens only when that list is empty or none of
  its folders still exist.
- What else survives a restart is listed in
  [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md).

## Not supported

- Nothing is listed here beyond the limits in the owner documents.
