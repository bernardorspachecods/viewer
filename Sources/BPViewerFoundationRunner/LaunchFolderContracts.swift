import BPViewerCore
import Foundation

extension Runner {
    /// Rules of the launch setting: which folder source each mode picks, and
    /// that the choice persists and defaults to reopening the last session.
    mutating func runLaunchFolderContracts() {
        let session = ["/s/a", "/s/b"]
        let defaults = ["/d/a", "/d/b"]

        expect(
            LaunchFolderPlanner.source(behavior: .reopenLast, existingSessionPaths: session, existingDefaultPaths: defaults)
                == .previousSession,
            "reopen-last restores the previous session when it has folders, even with defaults set"
        )
        expect(
            LaunchFolderPlanner.source(behavior: .reopenLast, existingSessionPaths: [], existingDefaultPaths: defaults)
                == .defaultFolders(defaults),
            "reopen-last with an empty session falls back to the default folders in order"
        )
        expect(
            LaunchFolderPlanner.source(behavior: .reopenLast, existingSessionPaths: [], existingDefaultPaths: [])
                == .homeFolder,
            "reopen-last with an empty session and empty defaults opens the home folder"
        )
        expect(
            LaunchFolderPlanner.source(behavior: .alwaysDefaults, existingSessionPaths: session, existingDefaultPaths: defaults)
                == .defaultFolders(defaults),
            "always-defaults ignores the previous session and opens the default folders"
        )
        expect(
            LaunchFolderPlanner.source(behavior: .alwaysDefaults, existingSessionPaths: session, existingDefaultPaths: [])
                == .homeFolder,
            "always-defaults with an empty list opens the home folder, not the previous session"
        )
        expect(
            LaunchFolderPlanner.source(behavior: .alwaysDefaults, existingSessionPaths: [], existingDefaultPaths: defaults)
                == .defaultFolders(defaults),
            "always-defaults with an empty session still opens the default folders"
        )
        expect(
            LaunchBehavior.allCases.map(\.rawValue) == ["reopenLast", "alwaysDefaults"],
            "launch behavior raw values are stable"
        )

        let legacyJSON = Data(#"{"schemaVersion":2,"global":{"theme":"dark"}}"#.utf8)
        let legacy = try? JSONDecoder().decode(AppState.self, from: legacyJSON)
        expect(
            legacy?.global.launchBehavior == LaunchBehavior.reopenLast.rawValue,
            "state without the launch key decodes as reopen-last"
        )

        let suiteName = "bp-viewer-launch-" + UUID().uuidString
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        MainActor.assumeIsolated {
            let storeDefaults = UserDefaults(suiteName: suiteName)!
            let first = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(first.launchBehavior == .reopenLast, "launch behavior defaults to reopen-last")
            first.setLaunchBehavior(.alwaysDefaults)
            let reloaded = WorkspaceSessionCoordinator(store: AppStateStore(defaults: storeDefaults))
            expect(reloaded.launchBehavior == .alwaysDefaults, "launch behavior persists across reloads")
        }
    }
}
