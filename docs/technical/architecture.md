---
bkf: document
description: "Technical architecture of the Swift code: the boundary between the Core and App targets, who coordinates state, and the rules that keep side effects out of views."
tags: [architecture, swift]
---

# Technical architecture

Module contents are listed by the member maps: [Sources/MAP.md](/Sources/MAP.md),
[ViewerApp](/Sources/ViewerApp/MAP.md), and [ViewerCore](/Sources/ViewerCore/MAP.md).
This document holds the rules that span them.

## Core and App boundary

- Logic that needs no UI framework belongs in `Sources/ViewerCore/`. The
  `Sources/ViewerApp/` target holds macOS integration and observable state.
- Core is UI-independent so the executable runners can exercise the same logic the
  app uses, without a window. See [verification.md](/docs/technical/verification.md).

## Coordination

- `AppModel`, isolated on the main actor, coordinates the presentation of one
  workspace. `WorkspaceWindowManager` keeps one model per native tab, and the tabs
  share one persistence coordinator.
- Specialized coordinators own the sub-workflows: rendering, editing, diff
  baselines, the tree, and persistence. They return values or events. `AppModel`
  applies them to its published state, and coordinators do not mutate `AppModel`.
- Views send intents to `AppModel` and render what it publishes. Views do not scan
  folders, compile, watch files, or persist state.
- Git is not exposed to the UI. The diff coordinator selects and retrieves the
  baselines. Core compares two in-memory texts and returns a result that does not
  depend on the document format.

## Where side effects live

- Scanning and watching: [filesystem-and-watching.md](/docs/technical/filesystem-and-watching.md).
- Rendering, compilation, and cancellation: [rendering.md](/docs/technical/rendering.md).
- Storage: [persistence.md](/docs/technical/persistence.md).
- Window composition and what views render: [ui-architecture.md](/docs/technical/ui-architecture.md).
- Authorization, Content Security Policy, and external files: [security.md](/docs/technical/security.md).
