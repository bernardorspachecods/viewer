---
bkf_version: "0.1"
description: "Entry map for the Viewer repository: the macOS app source, current behavior and architecture documents, manual fixtures, local build scripts, and repository conventions."
---

# Viewer repository

## Task routes

| Task | Start here |
| --- | --- |
| Change how the app is built or organized | [Technical architecture](/docs/technical/architecture.md) |
| Change window composition or UI interactions | [UI architecture](/docs/technical/ui-architecture.md) |
| Check a preview manually | [Fixture validation index](/Fixtures/MarkdownValidation/validation.md) |
| Follow the repository's work-round rules | [Agent instructions](/AGENTS.md) |

## Conventions

User-visible behavior documents, one per app area, are routed from [docs/MAP.md](/docs/MAP.md).

Structural rules for code and documents are in [AGENTS.md](/AGENTS.md). How to decide what a document holds is in the [repo library](/repo-library/modules/documentacao.md).

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
| Agent rules for this repository: structural rules for code and documents, and the `scripts/restart-app.sh` step that ends a work round changing app use. | [AGENTS.md](/AGENTS.md) |
| Manual validation fixtures for Markdown, link, and LaTeX previews: small input files, a local SVG, and a LaTeX project; these corpora contain no personal documents. | [MAP.md](/Fixtures/MAP.md) |
| Swift targets of the Viewer package: the shared core, macOS app, executable contract runners, and isolated tab prototypes; runners and prototypes exercise core seams rather than copy app logic. | [MAP.md](/Sources/MAP.md) |
| What remains open after the 2026-11-18 work round: decisions the owner must make, behavior that needs a live check, and known gaps in tests and cleanup. | [backlog.md](/backlog.md) |
| Current Viewer documentation: user-visible app behavior (one document per area) and technical architecture (one document per concern). | [MAP.md](/docs/MAP.md) |
| Procedures specific to the Viewer repository for agents: how to decide what a document holds. | [MAP.md](/repo-library/MAP.md) |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->

## Artifact references

- [Package.swift](/Package.swift) defines the Swift package products, targets, and dependencies.
- [restart-app.sh](/scripts/restart-app.sh) closes local app instances, builds the debug app, and opens it.
- [dev-run.sh](/scripts/dev-run.sh) rebuilds and restarts the app when `Sources/` changes.
- [build-app.sh](/scripts/build-app.sh) builds the local `.app` bundle and copies required resources.
- [check-file-size.sh](/scripts/check-file-size.sh) enforces the 500-line limit on Swift files in `Sources/` and `Tests/`; over-limit files are pinned in `scripts/file-size-baseline.json`, and a pin can only go down (`--update` lowers it).
- [check.sh](/scripts/check.sh) runs every check that works on this machine (build, both runners, size limits, `bkf validate`, `swift test`) and stops at the first failure.
- [check-function-size.sh](/scripts/check-function-size.sh) enforces the 150-line limit on Swift function, method, init, and computed property bodies in `Sources/` and `Tests/`; over-limit functions are pinned by file and name in `scripts/function-size-baseline.json`, and a pin can only go down (`--update` lowers it).
- [install-app.sh](/scripts/install-app.sh) builds the release app and installs it in `/Applications` or `BP_VIEWER_INSTALL_DIR`.
- [BPViewer-Info.plist](/Resources/BPViewer-Info.plist) supplies macOS app bundle metadata.
- [BPViewer.icns](/Resources/BPViewer.icns) is the app icon.
- [BPViewer-logo.svg](/Resources/BPViewer-logo.svg) is the vector app logo.
- [MarkdownAdapterTests.swift](/Tests/BPViewerAppTests/MarkdownAdapterTests.swift) contains package tests for the Markdown adapter and preview; the other app tests sit beside it in `Tests/BPViewerAppTests/`, one file per topic.

`.build/`, `.swiftpm/`, and `DerivedData/` hold generated build or package state, not durable context.

`Resources/` holds no secrets, project data, or build artifacts.
