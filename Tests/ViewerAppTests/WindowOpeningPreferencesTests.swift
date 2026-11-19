import Foundation
import Testing
@testable import ViewerCore

@Test("Older app state keeps remembered workspace sizing and the default reader size")
func legacyWindowOpeningPreferences() throws {
    let state = try JSONDecoder().decode(AppState.self, from: Data(#"{"global":{"theme":"light"}}"#.utf8))
    #expect(state.global.theme == "light")
    #expect(state.global.windowOpeningPreferences.workspaceOpeningSize == nil)
    #expect(state.global.windowOpeningPreferences.reader == .standard)
}

@MainActor
@Test("Window sizes persist independently and switching to remembered size retains custom dimensions")
func windowOpeningPreferencesPersist() throws {
    let suite = "ViewerWindowOpeningTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = AppStateStore(defaults: defaults)
    let workspace = WindowOpeningSize(width: 1400, height: 900)
    let reader = WindowOpeningSize(width: 1000, height: 650)
    let session = WorkspaceSessionCoordinator(store: store)
    session.setWindowOpeningPreferences(
        WindowOpeningPreferences(remembersWorkspaceSize: false, workspace: workspace, reader: reader)
    )

    let reopened = WorkspaceSessionCoordinator(store: store)
    #expect(reopened.windowOpeningPreferences.workspaceOpeningSize == workspace)
    #expect(reopened.windowOpeningPreferences.reader == reader)
    var preferences = reopened.windowOpeningPreferences
    preferences.remembersWorkspaceSize = true
    reopened.setWindowOpeningPreferences(preferences)

    let remembered = WorkspaceSessionCoordinator(store: store).windowOpeningPreferences
    #expect(remembered.workspaceOpeningSize == nil)
    #expect(remembered.workspace == workspace)
    #expect(remembered.reader == reader)
}

@Test("Window dimensions respect the app minimum and the available screen size")
func windowOpeningSizeFitsDisplay() {
    let available = CGSize(width: 1300, height: 800)
    #expect(WindowOpeningSize(width: 1600, height: 500).fitted(to: available)
        == CGSize(width: 1300, height: 600))
    #expect(WindowOpeningSize.standard.fitted(to: CGSize(width: 800, height: 500))
        == CGSize(width: 900, height: 600))
}
