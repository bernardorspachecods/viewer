---
bkf: document
description: "What remains open after the 2026-11-18 work round: decisions the owner must make, behavior that needs a live check, and known gaps in tests and cleanup."
tags: [backlog]
---

# Backlog

State on 2026-11-18, after the cleanup round. Everything the structural rules in
[AGENTS.md](/AGENTS.md) require is done except what is listed here. Remove an
entry when it is closed; do not keep history.

## Format

Each open item is one `###` entry. The heading is a short imperative or descriptive
sentence. The body has two parts:

- **Result:** what exists when the item is done.
- **Reason:** why the item matters, plus any detail it needs (files, links, open
  questions).

The Agentic app's board shows each `###` as one To-do card, and the heading is the
card's title. The body becomes the prompt of the agent that works on the item, so each
entry must stand alone: say what to do and why, without relying on the other entries.

## Decisions for the owner

### Decide whether Markdown previews run content JavaScript

**Result:** The owner decides whether Markdown previews run content JavaScript, and
[security.md](/docs/technical/security.md) records the decision.

**Reason:** The code sets `allowsContentJavaScript = true` in
`MarkdownWebPreview.swift`; the Word preview disables it. The older docs said no content
scripts. Open question in [security.md](/docs/technical/security.md).

### Decide whether Esc outside cell editing saves the CSV

**Result:** The owner decides whether Esc outside cell editing saves the CSV, and
[csv.md](/docs/behavior/csv.md) records the decision.

**Reason:** The code posts a save request on Esc. Open question in
[csv.md](/docs/behavior/csv.md).

### Decide whether unsaved drafts survive a restart

**Result:** The owner decides whether unsaved drafts survive a restart, and the docs
and the code state that decision.

**Reason:** Neither the docs nor the code say today.

### Decide whether the app keeps running with no workspace window

**Result:** The owner decides whether closing the last workspace window leaves the app
running with no window.

**Reason:** Today it does, so the global reply shortcut keeps working; "Show Workspace
Window" reopens it.

## Needs a live check in the app

These were verified by build, runners and tests only. Each entry needs a run in the app.

### Reproduce Cmd+W with one workspace and with several

**Result:** Cmd+W is confirmed or fixed for one workspace with no tabs and for several
workspaces.

**Reason:** Reported as working "only with two workspaces". The code showed no dependency
on the window count, so the fix (close the window when it has no document tabs) may not
be the real cause. Reproduce with one workspace and no tabs, then with several.

### Check the saved window frame with native window tabs

**Result:** The saved window frame is confirmed or fixed for every workspace window when
native window tabs are used.

**Reason:** AppKit may keep the frame of the first workspace window only. Verified only by
build, runners and tests so far.

### Check the terminal reader end to end

**Result:** The terminal reader is confirmed to work from the shortcut through the reader
window and its tab modes.

**Reason:** Covers the shortcut, Accessibility, keystrokes, reader window and tab modes.
Verified only by build, runners and tests so far.

### Check folder collapse buttons in the app

**Result:** The folder collapse buttons are confirmed to work, or the fixes are made.

**Reason:** Check the hover area, the two-step press, the root chevron, the saved state
across a restart, and the scroll speed of a large tree. If scrolling lags, make the button
always visible and muted. Verified only by build, runners and tests so far.

### Check the editor and previews after the file splits

**Result:** The editor and every preview kind are confirmed to work after the file splits.

**Reason:** Check typing, completion, list continuation, the gutter and diff highlights,
every preview kind, tab drag and drop, context menus, sidebar resize, and LaTeX sheets.
Verified only by build, runners and tests so far.

## Known gaps

### Cover the untested logic, or keep it listed as a gap

**Result:** Each untested area listed here has tests, or stays listed as a known gap.

**Reason:** SwiftUI and AppKit views and `SourceTextView*` are untested by decision. Also
untested: `AppModel` async flows, file watchers, generation guards, and
`JSONPreviewAdapter.sourceOffset`.

### Prove the tests added in the 2026-11-18 round can fail

**Result:** Each test added in the 2026-11-18 round fails when run against a deliberately
broken implementation.

**Reason:** These tests pass on the current code, but none was proven to fail on a broken
implementation.

### Decide whether default workspace folders need bookmarks

**Result:** The owner knows whether the app needs security-scoped bookmarks for default
workspace folders, and the code matches the answer.

**Reason:** Default workspace folders are stored as plain paths, without security-scoped
bookmarks. Not checked whether the app needs them.

### Remove the deprecated swift-testing dependency

**Result:** `Package.swift` no longer depends on the `swift-testing` package, and the build
still passes.

**Reason:** The toolchain warns that the package is deprecated. Removing it breaks the build
today, so the removal needs its own change.

### Stop check-function-size from counting nested functions twice

**Result:** `check-function-size.sh` counts a nested function once.

**Reason:** It counts a nested function both alone and inside its enclosing function.

## Cleanup left

### Use DocumentZoomLimits.clamped for the zoom clamp

**Result:** `AppModel.swift` and `AppModel+ZoomTheme.swift` use `DocumentZoomLimits.clamped`
instead of an inline clamp.

**Reason:** Anything used in more than one place is defined once (see AGENTS.md). The
inline copies can drift from the shared limit.

### Define the bib and tex extension checks once

**Result:** The `bib` and `tex` extension checks are defined once and used from
`AppModel+LatexEditing.swift`, `AppModel+Opening.swift`, `AppModel+LatexRoot.swift`,
`FileSystemFoundation.swift` and `LatexRootDiscovery.swift`.

**Reason:** The same checks repeat in five files. Anything used in more than one place is
defined once (see AGENTS.md).

### Decide whether to consolidate standardizedFileURL normalization

**Result:** The `standardizedFileURL` normalization is consolidated, or each call site is
confirmed to need its own form.

**Reason:** The normalization repeats across many call sites. It was not consolidated
because it is not provably identical everywhere.
