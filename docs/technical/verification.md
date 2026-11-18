---
bkf: document
description: "How the Viewer code is verified today: the two executable runners that exercise Core, the single app test file, and the areas with no automated coverage that must be treated as known gaps."
tags: [verification, gaps]
---

# Verification and known gaps

## What runs

- `swift run BPViewerContractRunner` covers the Markdown adapter and the LaTeX and
  process pipeline.
- `swift run BPViewerFoundationRunner` covers the filesystem, tree, tabs, persistence,
  editing, and merge foundations.
- The runners' roles, and why they exist, are in [Sources/MAP.md](/Sources/MAP.md).
- The only app test file is `Tests/BPViewerAppTests/MarkdownAdapterTests.swift`.
- The standard `swift test` target has not been verified on the current toolchain.
  The runners are the verification path.

## Known gaps

No automated coverage exists for these areas. A change there is verified by hand:

- SwiftUI rendering and AppKit event delivery; keyboard shortcuts; tab clicks;
  `WKWebView` behavior; lazy tree expansion; external file refresh.
- `AppModel` asynchronous tasks, `UserDefaults` isolation, watcher callbacks,
  render-generation cancellation, and the generation guards around `Task` scheduling.
- Permission-denied directories, the symlink policy, concurrent renames, and large
  filesystem performance.
