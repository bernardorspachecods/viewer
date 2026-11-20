---
bkf: document
description: "User-visible rules for workspaces (one native window tab per folder), the window header, document tabs, opening and closing, and what is restored at launch."
tags: [behavior, workspaces, tabs]
---

# Workspaces and tabs

## Workspaces

- A workspace is one local folder, shown as a native macOS window tab with its
  own header, sidebar, file tree, and document tab bar.
- A workspace window reuses its saved position. Its opening size follows
  [Settings > Windows](/docs/behavior/settings-and-persistence.md#settings).
- Capture windows opened as a fallback for `⌥⌘E` use the standard opening size.
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

- Buttons in the header, sidebar toolbar, document tab strip, and editing controls
  use a muted foreground at rest. The foreground gains contrast under the pointer
  and when pressed. Active editing modes keep a stronger foreground.
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
  A thin line in the theme's primary foreground color identifies the active
  document tab.
- `⌘W` closes the active document tab in the key window. When the window has no
  document tabs left, `⌘W` closes the workspace window instead, including when it
  is the only workspace window. The unsaved-changes rules in
  [editing-and-diff.md](/docs/behavior/editing-and-diff.md) still apply. The app
  keeps running after its last window closes.
- Holding `⌘W` (key repeat) closes tabs one by one but never closes the window: once
  the tabs are gone, the repeats do nothing. Closing the window takes a fresh press.
  A reader window counts its single tab as the last one, so a repeat does nothing
  there either. The rule stops a held key from closing a workspace window by accident
  after its last tab.
- A tab's context menu has copy path, reveal in sidebar (selects the file in the
  sidebar tree), reveal in Finder, reload, rename, duplicate, move to Trash, close
  tab, and close other tabs. An untitled tab has only the two close actions.
- Each document tab has its close button on the right. The `+` button stays at
  the right edge while the tabs scroll. Click it to create an in-memory Markdown
  tab, or drop a tab there to move it to the end. The first `Save` asks where to
  write the file. Unsaved untitled tabs are not restored after a restart.

## Split view

- Split View shows two document tabs of the workspace side by side, whatever their kind
  (Markdown, LaTeX, PDF, JSON, CSV, image, Word). It replaced the old editor-plus-preview
  split, which Markdown and JSON no longer have; LaTeX keeps its own `Source + PDF` button
  (see [latex-and-pdf.md](/docs/behavior/latex-and-pdf.md)).
- Enter it by dragging a tab onto the document area: the half where you release picks the
  pane, and a highlight shows which. Or use the tab's context menu, `Open in Split View`,
  which puts it in the right pane. Dropping a tab on a side replaces that pane; dropping the
  tab that is in the other pane swaps the two.
- Each pane is a complete tab: its own toolbar (icons only, to fit), outline, preview or
  editor mode, and zoom. The tab bar shows which pane has focus: its tab has the full underline and the other
  pane's tab a fainter one. Clicking a pane focuses it, and the header, zoom, search, Undo and Save act on it; search applies only to the
  focused pane.
- In the tab bar, selecting the other pane's tab moves focus to it; selecting any other tab
  replaces the focused pane's tab.
- Leave it with the `Split View` toolbar button (shown only while split) or by closing
  either tab; the remaining tab fills the area. There are always two panes at most, side by
  side, with a divider you can drag (each pane keeps at least 320 points).
- The split is not restored after a restart, and a reader window (no tab bar) has none.

## Focus mode

- The focus button in the header, and `⇧⌘F` (View > Focus Mode), show only the open
  document's preview: the header, the sidebar, the document tab bar, and the
  document's mode and edit bar (outline, split, diffs, Markdown editor, undo, save) are
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
- Focus mode is per window and is not saved. Leaving it brings back the sidebar
  state the window had before.
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

Development builds mark the app with DEV (Dock badge, window titles, header chip); see [architecture](/docs/technical/architecture.md#build-channels).
