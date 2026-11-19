---
bkf: document
description: "User-visible reply capture from terminal CLIs (⇧⌘E and ⌥⌘E), the standalone reader windows they open, snapshots of a preview selection, and the Accessibility and quit behavior that affects the global shortcut."
tags: [behavior, capture, snapshots, reader-window]
---

# Reply capture, reader windows, and snapshots

## Reply capture

- The global `⇧⌘E` shortcut works when a Terminal, iTerm2, Ghostty, WezTerm,
  Alacritty, Kitty, or Warp window is active. It asks the active CLI for its latest
  reply: `Ctrl+O` to Codex, or `/copy` to Claude Code.
- After you confirm that a new response is in the clipboard, Viewer saves it as
  Markdown and opens it:
  - `⇧⌘E` opens it in a standalone reader window.
  - `⌥⌘E` opens it as a tab of the last focused workspace window.
- Codex replies go to `~/Downloads/Codex Responses`. Claude Code replies go to
  `~/Downloads/Claude Code Responses`. Each folder is created when needed. A file
  is named for its CLI, and gets a numeric suffix if that name already exists.
- `⌥⌘E` opens the saved file in the last focused workspace window when that window is
  open. A reader window left focused by an earlier `⇧⌘E` is never the target; with no
  workspace window at all, or when the workspace window is minimized, the reply
  opens in a standalone capture window.
- Captured replies open at the default Markdown zoom.
- Sending keystrokes requires macOS Accessibility permission. After granting it,
  you may need to quit and reopen Viewer for it to take effect.
- How the capture engine is built, and what it needs from the app, is in
  [terminal-reader.md](/docs/technical/terminal-reader.md).
- Closing the last window leaves Viewer running, so the global shortcut stays
  available. Quitting Viewer ends the shortcut until the app is launched again.

## Reader windows

- `⇧⌘E` always opens a standalone reader window for the file and leaves workspace
  windows untouched.
- The reader shows the rendered reply. Its header has the document title, path,
  update time, status, and the zoom, screenshot, and theme controls. It has no
  sidebar, folder, workspace name, or tab bar.
- The editing toolbar appears while editing. Errors appear as a banner over the
  preview.
- `⌘W` closes the reader window rather than its tab while the window holds a single
  tab.
- Reader windows always open at the default size. They do not remember their size
  or position; see [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).

## Snapshots

- You can select an area of a preview, including content loaded by autoscroll, and
  open the selection in a floating window.
- Snapshots remain available across restarts until you close them.
- Where snapshot images are stored is described in
  [persistence.md](/docs/technical/persistence.md).
