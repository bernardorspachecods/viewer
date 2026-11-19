---
bkf: document
description: "What remains open after the 2026-11-18 work round: decisions the owner must make, behavior that needs a live check, and known gaps in tests and cleanup."
tags: [backlog]
---

# Backlog

State on 2026-11-18, after the cleanup round. Everything the structural rules in
[AGENTS.md](/AGENTS.md) require is done except what is listed here. Remove an
entry when it is closed; do not keep history.

## Decisions for the owner

| Question | Context |
| --- | --- |
| Should Markdown previews run content JavaScript? | The code sets `allowsContentJavaScript = true` in `MarkdownWebPreview.swift`; the Word preview disables it. The older docs said no content scripts. Open question in [security.md](/docs/technical/security.md). |
| Should Esc outside cell editing save the CSV? | The code posts a save request; open question in [csv.md](/docs/behavior/csv.md). |
| Do unsaved drafts survive a restart? | Neither the docs nor the code say. |
| Should the `Markdown Editor` button save when clicked to leave? | It leaves like `Esc`, which saves a changed draft. |
| Should the Markdown editor get the app's word completion back? | It was part of the raw editor and is not in `swift-markdown-engine`. |
| Should the Markdown editor's `swift-markdown-engine` stay pinned or be vendored? | One pinned revision, Apache 2.0, small upstream history. |
| Should `Markdown Editor` open at the position last read? | Opening starts at the top; only the outline jump moves the caret. |
| Should Quick Edit's block layer go? | `data-bp-editable` attributes, `markdownBlocks`, and `MarkdownBlockDocument`'s visual-edit methods have no caller from the UI after Quick Edit. |
| Do the new dependencies need an acknowledgements file? | `swift-markdown-engine` (Apache 2.0), highlight.js (BSD-3), and SwiftMath (MIT, with math fonts under their own licenses) are bundled. A distributed build needs their license texts, for example in Resources. |
| Should a link to a missing file say so? | Today the click does nothing and shows no message (`openLocalPreview` returns silently). |
| Should a link inside a reader window open a new tab there? | It does, but a reader has no tab bar, so the earlier document cannot be reached. |
| Should closing the last workspace window leave the app running with no window? | Today it does, so the global reply shortcut keeps working; "Show Workspace Window" reopens it. |

## Needs a live check in the app

These were verified by build, runners and tests only.

- The Markdown editor (`MarkdownLiveEditor`) was driven in the real app on
  2026-11-19 (reader window, split view, find, `⌘A`+`⌘B`, `⌘Z`, `Esc` save, Disk Diff
  with the old editor, a `/MAP.md` link opening the root file). Not checked yet: the
  caret after `⌘Z` (it went to the end of the document), the outline jump, two
  editor windows at once (`⌘B` must change only the focused one), local images,
  display math, dark mode, and `⌘S` with a `[[Page|Alias]]` link in the file.
- Cmd+W: reported as working "only with two workspaces". The code showed no
  dependency on the window count, so the fix (close the window when it has no
  document tabs) may not be the real cause. Reproduce with one workspace and
  no tabs, then with several.
- The saved window frame with native window tabs: AppKit may keep the frame of
  the first workspace window only.
- Terminal reader end to end: shortcut, Accessibility, keystrokes, reader window
  and tab modes.
- Folder collapse buttons: hover area, two-step press, the root chevron, saved
  state across a restart, and scroll speed of a large tree. If scrolling lags,
  make the button always visible and muted.
- Editor and previews after the file splits: typing, completion, list
  continuation, gutter and diff highlights, every preview kind, tab drag and
  drop, context menus, sidebar resize, LaTeX sheets.

## Known gaps

- No tests for SwiftUI and AppKit views or `SourceTextView*`, by decision.
  Also untested: `AppModel` async flows, file watchers, generation guards,
  `JSONPreviewAdapter.sourceOffset`.
- The tests added today pass on the current code; none was proven to fail on a
  deliberately broken implementation.
- Default workspace folders are stored as plain paths, without security-scoped
  bookmarks. Not checked whether the app needs them.
- `Package.swift` still depends on the `swift-testing` package; the toolchain
  warns it is deprecated, and removing it breaks the build today.
- `check-function-size.sh` counts a nested function both alone and inside its
  enclosing function.

## Cleanup left

- The zoom clamp is still inline in `AppModel.swift` and
  `AppModel+ZoomTheme.swift`; use `DocumentZoomLimits.clamped`.
- Extension checks for `bib` and `tex` repeat in `AppModel+LatexEditing.swift`,
  `AppModel+Opening.swift`, `AppModel+LatexRoot.swift`,
  `FileSystemFoundation.swift` and `LatexRootDiscovery.swift`.
- `standardizedFileURL` normalization repeats across many call sites and was
  not consolidated because it is not provably identical everywhere.
