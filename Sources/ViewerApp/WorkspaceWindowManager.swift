import AppKit
import ViewerCore
import SwiftUI

/// Owns the native macOS windows that represent open workspaces.
///
/// Each window keeps its own AppModel alive, so selecting a native window tab
/// does not tear down the tree, document tabs, or preview state.
@MainActor
final class WorkspaceWindowManager: NSObject, ObservableObject {
    static let shared = WorkspaceWindowManager()

    static let tabbingIdentifier = "com.bernardopacheco.viewer.workspace"
    private static let frameAutosaveName = "com.bernardopacheco.viewer.workspace-frame"

    let session: WorkspaceSessionCoordinator
    var openMainWindow: (() -> Void)?
    @Published private(set) var activeModel: AppModel? {
        didSet {
            if let activeModel, activeModel.presentation == .workspace {
                lastWorkspaceModel = activeModel
            }
        }
    }
    /// The last focused ordinary workspace model, so a capture tab never lands in a reader window.
    weak var lastWorkspaceModel: AppModel?

    // Internal, not private: the terminal reader's window host extends this
    // type in TerminalReader/, and it reads the same window state.
    var models: [ObjectIdentifier: AppModel] = [:]
    var windows: [ObjectIdentifier: NSWindow] = [:]
    var lastKnownModel: AppModel?
    var lastKnownWindow: NSWindow?
    private var didRestoreWorkspaces = false
    private var keyWindowObserver: NSObjectProtocol?
    private var isTerminating = false
    private var terminationObserver: NSObjectProtocol?

    private override init() {
        session = WorkspaceSessionCoordinator()
        super.init()

        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor [weak self] in
                self?.activate(window: window)
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.prepareForTermination()
            }
        }
    }

    func register(model: AppModel?, window: NSWindow) {
        guard let model else { return }

        let id = ObjectIdentifier(window)
        let isNewWindow = windows[id] == nil
        models[id] = model
        windows[id] = window
        lastKnownModel = model
        lastKnownWindow = window

        if model.presentation.isStandalone {
            window.tabbingMode = .disallowed
        } else {
            window.tabbingMode = .preferred
            window.tabbingIdentifier = Self.tabbingIdentifier
            if isNewWindow {
                restoreWorkspaceFrame(window)
            }
        }
        updateWindowTitle(window, for: model)
        model.attach(to: window)

        if window.isKeyWindow || window.isMainWindow {
            activeModel = model
        }

        if let rootURL = model.rootURL,
           !session.openWorkspacePaths.contains(session.workspaceKey(for: rootURL)) {
            let existing = session.openWorkspacePaths.map(URL.init(fileURLWithPath:))
            session.setOpenWorkspaces(existing + [rootURL], activeRoot: rootURL)
        }

        // The first ordinary workspace window restores the session, falling back
        // to the default folders. It may start without a root.
        guard !didRestoreWorkspaces, model.presentation == .workspace else { return }
        didRestoreWorkspaces = true
        DispatchQueue.main.async { [weak self, weak model] in
            guard let self, let model else { return }
            self.restoreWorkspaces(anchoredAt: model)
        }
    }

    func unregister(window: NSWindow) {
        let id = ObjectIdentifier(window)
        let removedModel = models.removeValue(forKey: id)
        windows.removeValue(forKey: id)

        if activeModel === removedModel {
            activeModel = keyWindowModel() ?? models.values.first
        }
        guard !isTerminating else { return }
        persistWorkspaceLayout()
    }

    func prepareForTermination() {
        guard !isTerminating else { return }
        isTerminating = true
        persistWorkspaceLayout()
    }

    func activate(window: NSWindow) {
        guard let model = models[ObjectIdentifier(window)] else { return }
        activeModel = model
        persistWorkspaceLayout()
    }

    func chooseAndOpenWorkspace(from sourceModel: AppModel? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Workspace"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspace(url, from: sourceModel ?? activeModel)
    }

    func openWorkspace(
        _ url: URL,
        opening documents: [URL] = [],
        from sourceModel: AppModel? = nil
    ) {
        let rootURL = url.resolvingSymlinksInPath().standardizedFileURL
        guard isDirectory(rootURL) else { return }

        if let sourceModel,
           let sourceWindow = sourceModel.nativeWindow {
            register(model: sourceModel, window: sourceWindow)
        }

        if let emptyModel = sourceModel ?? activeModel,
           emptyModel.rootURL == nil {
            let emptyWindow = emptyModel.nativeWindow ?? window(for: emptyModel)
            emptyModel.openRoot(rootURL)
            if let emptyWindow {
                register(model: emptyModel, window: emptyWindow)
                updateWindowTitle(emptyWindow, for: emptyModel)
            }
            documents.forEach { emptyModel.openDocument(url: $0) }
            persistWorkspaceLayout()
            return
        }

        if let existing = window(for: rootURL),
           let model = models[ObjectIdentifier(existing)] {
            existing.tabGroup?.selectedWindow = existing
            existing.makeKeyAndOrderFront(nil)
            documents.forEach { model.openDocument(url: $0) }
            persistWorkspaceLayout()
            return
        }

        let model = AppModel(
            workspaceSession: session,
            initialRootURL: rootURL,
            restoresLastWorkspace: false
        )
        let window = makeWindow(for: model)
        register(model: model, window: window)

        if let anchor = anchorWindow(excluding: window, preferredModel: sourceModel) {
            anchor.addTabbedWindow(window, ordered: .above)
            anchor.tabGroup?.selectedWindow = window
        } else {
            window.makeKeyAndOrderFront(nil)
        }

        documents.forEach { model.openDocument(url: $0) }
        persistWorkspaceLayout()
    }

    func closeActiveTabInKeyWindow() {
        guard let keyWindow = NSApp.keyWindow else { return }
        if let snapshotWindow = keyWindow as? SnapshotPanel {
            snapshotWindow.performClose(nil)
            return
        }
        guard let model = models[ObjectIdentifier(keyWindow)] else { return }
        // With no document tab left there is nothing to close inside the window,
        // so Cmd-W closes the window. A reader window holds a single reply, so its
        // last tab closes the window too. performClose runs the unsaved-changes guard.
        if model.tabs.isEmpty || (model.presentation.isReader && model.tabs.count <= 1) {
            keyWindow.performClose(nil)
            return
        }
        model.closeActiveTab()
    }

    func modelForActiveWindow(fallback: AppModel? = nil) -> AppModel? {
        keyWindowModel() ?? activeModel ?? fallback
    }

    /// Opens each file in its own reader window (no sidebar or top bar), or
    /// focuses the reader window that already shows it.
    func openReaderWindows(for urls: [URL]) {
        for url in urls {
            let file = url.resolvingSymlinksInPath().standardizedFileURL
            if let existing = models.first(where: { _, model in
                model.presentation.isReader && model.tabs.contains { $0.url.standardizedFileURL == file }
            }), let window = windows[existing.key] {
                bringForward(window, model: existing.value)
                continue
            }

            let (readerModel, readerWindow) = makeStandaloneWindow(.reader)
            _ = readerModel.openDocument(url: file)
            // The hosting view resets the title after its first layout, so set it
            // again on the next run loop turn.
            let title = "Viewer — \(file.lastPathComponent)"
            readerWindow.title = title
            DispatchQueue.main.async { [weak readerWindow] in
                readerWindow?.title = title
            }
            bringForward(readerWindow, model: readerModel)
        }
    }

    /// Opens the main workspace window when the app started without one, as
    /// happens when it is launched by opening a file. Reader windows stay in front.
    func ensureWorkspaceWindow() {
        guard !models.values.contains(where: { $0.presentation == .workspace }) else { return }
        openMainWindow?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            for (id, model) in models where model.presentation.isStandalone {
                windows[id]?.orderFrontRegardless()
            }
        }
    }

    func synchronizeGlobalPreferences(from source: AppModel) {
        for model in models.values where model !== source {
            model.applySharedPreferences(from: source)
        }
    }

    /// Creates a standalone window (reader or capture) with its own model. The
    /// caller adds content, then brings the window forward.
    func makeStandaloneWindow(_ presentation: WindowPresentation) -> (model: AppModel, window: NSWindow) {
        let model = AppModel(
            workspaceSession: session,
            restoresLastWorkspace: false,
            persistsSharedConfiguration: false
        )
        model.sidebarVisible = false
        model.presentation = presentation
        let window = makeWindow(for: model)
        register(model: model, window: window)
        return (model, window)
    }

    private func restoreWorkspaces(anchoredAt initialModel: AppModel) {
        let initialRootPath = initialModel.rootURL.map(session.workspaceKey(for:))
        let validPaths = session.openWorkspacePaths.filter { isDirectory(URL(fileURLWithPath: $0)) }
        let validDefaults = session.defaultWorkspaceFolderPaths
            .map(URL.init(fileURLWithPath:))
            .filter { isDirectory($0) }
            .map(\.path)

        let source = LaunchFolderPlanner.source(
            behavior: session.launchBehavior,
            existingSessionPaths: validPaths,
            existingDefaultPaths: validDefaults
        )
        switch source {
        case let .defaultFolders(folders) where initialModel.rootURL == nil:
            openDefaultWorkspaces(folders.map(URL.init(fileURLWithPath:)), anchoredAt: initialModel)
            return
        case .homeFolder where initialModel.rootURL == nil:
            initialModel.openRoot(FileManager.default.homeDirectoryForCurrentUser)
            persistWorkspaceLayout()
            return
        case .homeFolder, .defaultFolders, .previousSession:
            break
        }

        for path in validPaths where path != initialRootPath {
            openWorkspace(URL(fileURLWithPath: path))
        }

        if let activePath = session.activeWorkspacePath,
           let activeWindow = window(for: URL(fileURLWithPath: activePath)) {
            activeWindow.tabGroup?.selectedWindow = activeWindow
            activeWindow.makeKeyAndOrderFront(nil)
        } else {
            initialModelWindow()?.makeKeyAndOrderFront(nil)
        }

        persistWorkspaceLayout()
    }

    /// Opens the given existing default workspace folders, the first in the
    /// initial window and the rest as native tabs, in list order. The caller
    /// has already checked that the folders exist and chosen the home folder
    /// when there are none.
    private func openDefaultWorkspaces(_ folders: [URL], anchoredAt initialModel: AppModel) {
        guard let first = folders.first else { return }

        for folder in folders {
            openWorkspace(folder, from: initialModel)
        }
        if let firstWindow = window(for: first) {
            firstWindow.tabGroup?.selectedWindow = firstWindow
            firstWindow.makeKeyAndOrderFront(nil)
        }
        persistWorkspaceLayout()
    }

    /// Creates the default frame. Workspace windows apply launch preferences on registration.
    func makeWindow(for model: AppModel) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: CGFloat(WindowOpeningSize.standard.width),
                height: CGFloat(WindowOpeningSize.standard.height)
            ),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: RootView().environmentObject(model)
        )
        if model.presentation.isStandalone {
            window.center()
        }
        return window
    }

    /// Native workspace tabs share a saved frame. Apply the custom size after
    /// restoring the saved position, then attach autosave for later resizes.
    private func restoreWorkspaceFrame(_ window: NSWindow) {
        let name = Self.frameAutosaveName
        guard window.frameAutosaveName != name else { return }
        let restored = window.setFrameUsingName(name)
        if let openingSize = session.windowOpeningPreferences.workspaceOpeningSize {
            window.applyOpeningSize(openingSize)
        }
        if !restored {
            window.center()
        }
        _ = window.setFrameAutosaveName(name)
    }

    func bringForward(_ window: NSWindow, model: AppModel) {
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        activeModel = model
    }

    func window(for rootURL: URL) -> NSWindow? {
        let path = session.workspaceKey(for: rootURL)
        return windows.values.first { window in
            guard let model = models[ObjectIdentifier(window)], let modelRoot = model.rootURL else {
                return false
            }
            return session.workspaceKey(for: modelRoot) == path
        }
    }

    func window(for model: AppModel) -> NSWindow? {
        guard let windowID = models.first(where: { $0.value === model })?.key else {
            return nil
        }
        return windows[windowID]
    }

    private func anchorWindow(
        excluding excludedWindow: NSWindow? = nil,
        preferredModel: AppModel? = nil
    ) -> NSWindow? {
        if let preferredModel,
           let window = window(for: preferredModel),
           window !== excludedWindow {
            return window
        }
        if let activeModel,
           let window = windows.first(where: { $0.value === activeModel })?.value {
            if window !== excludedWindow {
                return window
            }
        }
        if let keyWindow = keyWindowModel(),
           let window = windows.first(where: { $0.value === keyWindow })?.value,
           window !== excludedWindow {
            return window
        }
        return windows.values.first { $0 !== excludedWindow }
    }

    private func initialModelWindow() -> NSWindow? {
        windows.values.first { window in
            guard let model = models[ObjectIdentifier(window)] else { return false }
            return model.rootURL?.path == session.activeWorkspacePath
        } ?? windows.values.first
    }

    private func keyWindowModel() -> AppModel? {
        guard let keyWindow = NSApp.keyWindow else { return nil }
        return models[ObjectIdentifier(keyWindow)]
    }

    private func updateWindowTitle(_ window: NSWindow, for model: AppModel) {
        let title = model.rootURL?.lastPathComponent ?? "Viewer"
        window.title = title
        window.tab.title = title
    }

    private func persistWorkspaceLayout() {
        let orderedWindows: [NSWindow]
        if let group = anchorWindow()?.tabGroup {
            orderedWindows = group.windows
        } else {
            orderedWindows = Array(windows.values)
        }

        let roots = orderedWindows.compactMap { window in
            models[ObjectIdentifier(window)]?.rootURL
        }
        guard !roots.isEmpty else {
            session.setOpenWorkspaces([], activeRoot: nil)
            return
        }

        session.setOpenWorkspaces(
            roots,
            activeRoot: activeModel?.rootURL ?? keyWindowModel()?.rootURL
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
