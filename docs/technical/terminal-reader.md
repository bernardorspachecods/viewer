---
bkf: document
description: "Technical boundary of the terminal reader engine that captures a Codex or Claude Code reply from a terminal and saves it as Markdown: what lives in the engine, what it needs from the app, its permissions, and its known gaps."
tags: [architecture, capture, reader-window]
---

# Terminal reader engine

The user-visible rules are in
[reply-capture-and-snapshots.md](/docs/behavior/reply-capture-and-snapshots.md),
which owns the behavior. This document owns how the engine is built.

## What the engine is

The engine captures the latest reply of a terminal CLI, saves it as Markdown, and
asks the app to show it. It runs in the App target because it depends on AppKit,
Carbon hot keys, and the Accessibility API. It is separate from the workspace
code, which owns every window.

Code lives in `Sources/ViewerApp/TerminalReader/`:

| File | Responsibility |
| --- | --- |
| `TerminalReplyController.swift` | Capture flow: frontmost terminal check, copy request, clipboard polling, Accessibility prompt, alerts. |
| `TerminalReplyShortcut.swift` | Global `⇧⌘E` and `⌥⌘E` registration: Carbon hot keys with a global key monitor as fallback. |
| `TerminalReplyKeystrokes.swift` | Keystrokes sent to the CLI: `Ctrl+O` for Codex, `/copy` and Return for Claude Code. |
| `TerminalReplyAccessibility.swift` | Reads the focused terminal window to tell Codex from Claude Code and to detect Claude Code's copy picker. |
| `TerminalReplyFiles.swift` | Chooses the save folder in Downloads per CLI and creates it when needed. |
| `TerminalReplyHost.swift` | The boundary protocols and the destination enum. |
| `TerminalReplyWindowHost.swift` | The app's side of the boundary: which window receives the reply. |

The pure rules have no AppKit dependency. They live in
`Sources/ViewerCore/TerminalReplyRules.swift`: terminal bundle identifiers,
client detection from window text, copy-picker detection, and reply file naming
with its numeric suffix.

## Boundary with the app

The engine talks to the app through two protocols, both in
`TerminalReplyHost.swift`:

- `TerminalReplyHost.showReplyWindow(for:)` takes a destination, `readerWindow`
  (`⇧⌘E`) or `workspaceTab` (`⌥⌘E`). It makes sure a window exists and returns the
  target that receives the reply, or nil when none can be shown.
- `TerminalReplyTarget.saveReply(markdown:to:)` creates the document with the
  reply and saves it to the file the engine chose. It returns false when saving
  failed.

The engine never creates a window and never reads workspace state. It also never
touches `AppModel` beyond the save call. `WorkspaceWindowManager` conforms to the
host and `AppModel` conforms to the target, both in `TerminalReplyWindowHost.swift`.

The order is part of the contract. The window is shown first, and the save
folder is resolved after that. If no window can be shown, the engine stops
before touching the disk.

## Why it is separate

- The capture flow is independent of the document model. Changing the reader or
  the workspace should not change how the shortcut and the clipboard work, and
  the reverse holds too.
- The window logic stays with the app, which owns every native window, tab group,
  and the restore-at-launch rules.
- The pure rules can be checked from the foundation runner without AppKit.

## What the app provides

- A `WorkspaceWindowManager` that can create a standalone reader or capture
  window (`makeStandaloneWindow`) and bring a workspace window forward. The
  Finder route for Markdown files uses the same reader creation, so the reader
  window stays owned by the app.
- A `WindowPresentation` value on each model (`workspace`, `standalone`, `reader`).
  The engine does not read it; the app sets it when it creates the window.

## Permissions and limits

- Sending keystrokes and reading the window needs macOS Accessibility permission
  for the app. The app asks once per session. macOS may keep the previous state
  until the app is restarted, and the engine tells the user so.
- The shortcut only acts when the frontmost app is in the terminal list. Other
  apps are not read.
- Capture polls the clipboard for up to three seconds. A reply is accepted only
  when the clipboard change count moves and the text is non-empty.
- A press within 0.4 seconds of the last accepted press is ignored.
- The engine writes only under `~/Downloads/<CLI> Responses/`. It never writes
  into a workspace folder.

## Known gaps

- The capture flow calls the system Accessibility and keystroke APIs and needs a
  live Mac with a terminal running a CLI. The runners cover only the pure rules,
  so the flow itself is not verified by an automated check.
- If the Downloads folder cannot be created, the alert says that Downloads could
  not be found. It is also shown for other file errors, which is the current
  wording rather than an intended message.
- For Claude Code the engine does not wait for the copy picker to be detected: while nothing is copied it sends a blind Return about 0.2, 0.5, and 1.0 seconds after the Return that runs `/copy` (polling every 40 ms), and also confirms the picker when Accessibility sees it. Return on an empty Claude Code prompt does nothing, so the extra presses are harmless when `/copy` copies directly. A wording change in the picker therefore does not leave the CLI stuck.
- The Claude Code picker is detected by its text. A change in the CLI's wording
  breaks detection, and the user then has to select the copy option by hand.
