---
bkf: document
description: "How app state is stored: the versioned Codable model in Core, the single UserDefaults access point, the keys that must not be renamed, and what is kept out of stored state."
tags: [architecture, persistence]
---

# Persistence

What users see survive a restart is in
[settings-and-persistence.md](/docs/behavior/settings-and-persistence.md); this
document covers how it is stored.

- Persisted state is a `Codable` model with a `schemaVersion`, in
  `Sources/ViewerCore/SessionStateModels.swift`. Changes to it must keep older state
  loading.
- Storage is JSON in `UserDefaults`. Only `WorkspaceSessionCoordinator` reads and
  writes it.
- The show-selected-files toggle keeps its original `compatibleOnly` key. Renaming
  the key would drop the value users already saved.
- The workspace order and the active workspace are stored to restore the window
  tabs at launch. The launch fallback is in
  [workspaces-and-tabs.md](/docs/behavior/workspaces-and-tabs.md).
- AppKit saves the workspace frame under the shared autosave name in
  `WorkspaceWindowManager`. When a custom workspace size is set, the manager applies
  it after restoring the frame. The opening preferences are part of the global
  Codable state. Reader and capture windows have no frame autosave name.
- Transient state is not stored: diff state exists only in memory, and rendered HTML,
  PDFs, logs, and raw content are not session state.
- Snapshot PNG files are stored in Application Support, outside the repository.
  The app does not write build artifacts into the user's source folder; see
  [security.md](/docs/technical/security.md).
