---
bkf: document
description: "How the Viewer code is verified: the one command that runs every check on this machine, what each check covers, and the areas with no automated coverage that must be treated as known gaps."
tags: [verification, gaps]
---

# Verification and known gaps

## Run everything

```bash
scripts/check.sh
```

The script runs these steps in order and stops at the first failure, printing the
failing step's last output and a summary. It exits 1 on any failure:

1. `swift build`
2. `swift run BPViewerContractRunner`: Markdown adapter, LaTeX discovery and render
   contracts, process pipeline.
3. `swift run BPViewerFoundationRunner`: filesystem, tree, file kinds, tabs,
   persistence, Markdown editing and merge, JSON, CSV, zoom, folder collapse.
4. `scripts/check-file-size.sh` and `scripts/check-function-size.sh`: the 500-line
   and 150-line structural limits, with their shrink-only baselines.
5. `bkf validate .` and `bkf validate repo-library` in `repo-library/`.
6. `swift test`: the app test target in `Tests/BPViewerAppTests/`.

The runners' roles are in [Sources/MAP.md](/Sources/MAP.md).

## What `swift test` covers

`swift test` runs on this machine: the toolchain (Swift 6.2, Command Line Tools)
ships the Swift Testing module, and the package no longer depends on the separate
`swift-testing` package. Its files are one per topic: Markdown preview, workspace
files and tree, tabs, images, CSV, LaTeX, editing modes, diff, editor layout, merge,
Git HEAD baseline, file kind filter. Shared test doubles are in
`TestDoubles.swift`. A new behavior that is logic in Core ships with a test in this
target or, where the runner is the natural place, in a runner scenario.

## Known gaps

No automated coverage exists for these areas. A change there is verified by hand:

- SwiftUI rendering and AppKit event delivery; keyboard shortcuts; tab clicks;
  `WKWebView` behavior; lazy tree expansion; external file refresh.
- `AppModel` asynchronous tasks, `UserDefaults` isolation, watcher callbacks,
  render-generation cancellation, and the generation guards around `Task` scheduling.
- Permission-denied directories, the symlink policy, concurrent renames, and large
  filesystem performance.
- The JSON editor's mapping from formatted to source offsets
  (`JSONPreviewAdapter.sourceOffset`) has no direct test.
- Real Git and real LaTeX toolchains: the Git tests use scripted process doubles, and
  the LaTeX pipeline is checked only where a local toolchain exists.
