---
bkf: document
description: "User-visible rules for workspaces (one native window tab per folder), the window header, document tabs, opening and closing, and what is restored at launch."
tags: [behavior, workspaces, tabs]
---

# Workspaces and tabs

## Workspaces

- A workspace is one local folder, shown as a native macOS window tab with its
  own header, sidebar, file tree, and document tab bar.
- A workspace window reopens at the size and position it had when it was last
  moved or resized, and 1200 × 780 before any is saved. Reader and capture windows
  always open at the default size.
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
- A tab's context menu has copy path, reveal in sidebar (selects the file in the
  sidebar tree), reveal in Finder, reload, rename, duplicate, move to Trash, close
  tab, and close other tabs. An untitled tab has only the two close actions.
- The `+` button at the end of the tab bar creates an in-memory Markdown tab with
  no path. The first `Save` opens a panel to choose the `.md` file. Such a tab is
  not restored after a restart.

## Focus mode

- The focus button in the header, and `⇧⌘F` (View > Focus Mode), show only the open
  document's preview: the header, the sidebar, the document tab bar, and the
  document's mode and edit bar (outline, split, diffs, raw Markdown, undo, save) are
  hidden, and the document fills the window. Leave focus mode to use them. Choose the button again, press `⇧⌘F`, or press
  Esc, to leave it.
- While focus mode is on, a small button at the top-right of the document also leaves
  it. It is faint until the pointer is over it. Reader windows have it too.
- Focus mode also hides the window's title bar (its title and the traffic lights) and
  the native tab strip of workspace tabs. The window stays a normal window, not macOS
  full screen, and it can still be dragged by its background. Leaving focus mode puts
  back the title bar the window had before, and shows the tab strip again.
- Focus mode is per window: hiding the tab strip in one window does not hide it in
  the others. A window with a single tab has no strip, so nothing changes for it.
- `⌘W` still closes the active tab or window in focus mode.
- Esc leaves focus mode only when no other view takes it first. Editors, the find
  bar, and dialogs keep their own Esc behavior, and Esc does nothing when focus mode
  is off.
- `⌘F` still opens the find bar inside the focused view.
- Focus mode is per window and is not saved: every launch starts with it off. It
  does not change the saved sidebar setting, so leaving focus mode brings back the
  sidebar state the window had before.
- Standalone reader windows and workspace windows both support it.

## Launch and restore

- Settings > Workspaces > On Launch chooses one of two modes:
  - "Reopen the last workspaces" (the default): the app restores every existing
    workspace tab in its previous order and focuses the last active one. References
    to folders or tabs that no longer exist are removed. If nothing can be restored,
    the default workspace folders are opened (below).
  - "Always open the default workspaces": the previous session's workspaces are
    ignored and the default workspace folders are opened (below). The per-workspace
    state of those folders, such as their tabs, is still restored.
- The default workspace folders, opened in list order: the first in the initial
  window, the rest as native tabs. Folders that no longer exist are skipped. The
  home folder opens only when that list is empty or none of its folders still exist.
- What else survives a restart is listed in
  [settings-and-persistence.md](/docs/behavior/settings-and-persistence.md).

## Not supported

- Nothing is listed here beyond the limits in the owner documents.
