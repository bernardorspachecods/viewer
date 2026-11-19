import AppKit
import BPViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let bpViewerOpenFiles = Notification.Name("bp-viewer.open-files")
}

struct LatexRootSelectionRequest: Identifiable {
    let id: String
    let tabID: String
    let openedFile: URL
    let projectRoot: URL
    let candidates: [LatexRootCandidate]
}

struct LatexExternalDependencyRequest: Identifiable {
    let id: String
    let tabID: String
    let rootURL: URL
    let projectRoot: URL
    let dependencies: [LatexExternalDependency]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var theme: AppThemePreference
    @Published var rootURL: URL?
    @Published var nodes: [FileNode] = []
    @Published var tabs: [DocumentTab] = []
    @Published var activeTabID: String?
    @Published var treeQuery = ""
    @Published var showSelectedFilesOnly = true
    /// File kinds shown by "Show selected files only", mirrored from the shared session.
    @Published var selectedFileKinds: Set<DocumentKind>
    @Published var extraFileExtensions: [String]
    @Published var showHiddenFiles = false
    @Published var expandedPaths: Set<String> = []
    /// The workspace root's listing is hidden, mirrored from the tree session.
    @Published var isRootCollapsed = false
    @Published var treeRevealTargetID: String?
    /// Shows items in Finder; replaced in tests to record the request.
    var finderRevealer: FinderRevealing = SystemFinderRevealer()
    @Published var treeScrollOffset: Double = 0
    @Published var sidebarVisible = true
    /// Shows only the open document's preview (header, sidebar and tab bar hidden). Per window, not stored.
    @Published var isFocusMode = false
    /// How this model's window presents it. Set once, when the window is created.
    @Published var presentation: WindowPresentation = .workspace
    @Published var sidebarWidth: Double = 280
    /// Default workspace folders, mirrored from the shared session so Settings
    /// reads the same list from any window.
    @Published var defaultWorkspaceFolders: [String]
    /// What launch opens, mirrored from the shared session like the folder list.
    @Published var launchBehavior: LaunchBehavior
    @Published var previewZoom: Double = 1.0
    @Published var defaultMarkdownZoom: Double = 1.0
    @Published var defaultLatexZoom: Double = 1.0
    @Published var latexShellEscapeMode: LatexShellEscapeMode = .disabled
    @Published var isFindBarVisible = false
    @Published var findQuery = ""
    @Published var findRequestID = 0
    @Published var findBackwards = false
    @Published var findTarget: FindTarget = .preview
    @Published var findMatchCount: Int?
    @Published var isScanningTree = false
    @Published var isFilteringTree = false
    @Published var pendingRootURL: URL?
    @Published var showingRootChangeConfirmation = false
    @Published var isPendingRootChange = false
    @Published var pendingCloseRequest: PendingCloseRequest?
    @Published var showingPendingCloseConfirmation = false
    @Published var isPendingWindowClose = false
    @Published var pendingFileMoveRequest: PendingFileMoveRequest?
    @Published var showingFileMoveConfirmation = false
    @Published var pendingInvalidJSONTabID: String?
    @Published var showingInvalidJSONConfirmation = false
    @Published var pendingGitDiscardTabID: String?
    @Published var showingGitDiscardConfirmation = false
    @Published var pendingLatexRootSelection: LatexRootSelectionRequest?
    @Published var pendingLatexExternalDependencies: LatexExternalDependencyRequest?
    @Published var isSnapshotCaptureActive = false
    @Published var isPerformingFileOperation = false

    let workspaceSession: WorkspaceSessionCoordinator
    let persistsSharedConfiguration: Bool
    let documentOpenCoordinator = DocumentOpenCoordinator()
    let snapshotArtifactStore = SnapshotArtifactStore()
    lazy var snapshotWindowManager = SnapshotWindowManager { [weak self] id in
        self?.removeSnapshot(id: id)
    }
    lazy var workspaceTreeSession = WorkspaceTreeSession(
        onStateChange: { [weak self] state in
            self?.applyWorkspaceTreeState(state)
        },
        onPersistenceRequested: { [weak self] in
            self?.persistState()
        }
    )
    lazy var documentRenderCoordinator = DocumentRenderCoordinator { [weak self] event in
        self?.handleDocumentRenderEvent(event)
    }
    lazy var documentEditCoordinator = DocumentEditCoordinator()
    let documentDiffCoordinator: DocumentDiffCoordinator
    lazy var activeDocumentWatcher = ActiveDocumentWatcher { [weak self] change in
        self?.handleActiveDocumentChange(change)
    }
    var pendingOpenURLs: [URL] = []
    private var openFilesObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var localKeyMonitor: Any?
    weak var pendingWindow: NSWindow?
    var pendingBatchCloseIDs: Set<String> = []
    var readingPositionPersistenceTask: Task<Void, Never>?
    var fileOperationTask: Task<Void, Never>?
    var gitDiscardTask: Task<Void, Never>?
    var latexRenderDebounceTasks: [String: Task<Void, Never>] = [:]
    var markdownRenderDebounceTasks: [String: Task<Void, Never>] = [:]
    var markdownUndoGroupTimes: [String: TimeInterval] = [:]
    var activeSecurityScopedRootURL: URL?
    private weak var attachedWindow: NSWindow?
    /// Keeps the attached window's title bar and tab strip in step with focus mode.
    private(set) var focusChrome: WindowFocusChromeSync?

    init(
        documentDiffCoordinator: DocumentDiffCoordinator = DocumentDiffCoordinator(),
        workspaceSession: WorkspaceSessionCoordinator = WorkspaceSessionCoordinator(),
        initialRootURL: URL? = nil,
        restoresLastWorkspace: Bool = true,
        persistsSharedConfiguration: Bool = true
    ) {
        self.documentDiffCoordinator = documentDiffCoordinator
        self.workspaceSession = workspaceSession
        self.persistsSharedConfiguration = persistsSharedConfiguration
        let configuration = workspaceSession.configuration
        theme = AppThemePreference(rawValue: configuration.theme) ?? .dark
        sidebarVisible = configuration.sidebarVisible
        sidebarWidth = configuration.sidebarWidth
        latexShellEscapeMode = LatexShellEscapeMode(rawValue: configuration.latexShellEscapeMode) ?? .disabled
        defaultWorkspaceFolders = workspaceSession.defaultWorkspaceFolderPaths
        launchBehavior = workspaceSession.launchBehavior
        selectedFileKinds = workspaceSession.selectedFileKinds
        extraFileExtensions = workspaceSession.extraFileExtensions
        defaultMarkdownZoom = min(max(configuration.defaultMarkdownZoom, 0.7), 2.0)
        defaultLatexZoom = min(max(configuration.defaultLatexZoom, 0.7), 2.0)

        openFilesObserver = NotificationCenter.default.addObserver(
            forName: .bpViewerOpenFiles,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let urls = notification.object as? [URL] else { return }
            Task { @MainActor [weak self] in
                guard let self, self.shouldHandleWindowEvents else { return }
                self.openExternalURLs(urls)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalKeyDown(event)
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.snapshotWindowManager.prepareForTermination()
                self.persistState()
                self.stopSecurityScopedAccess()
            }
        }

        if let initialRootURL, isDirectory(initialRootURL) {
            openRoot(initialRootURL)
        } else if restoresLastWorkspace,
                  workspaceSession.launchBehavior == .reopenLast,
                  let path = workspaceSession.activeWorkspacePath {
            let pathURL = URL(fileURLWithPath: path)
            let url = (try? workspaceSession.resolveSecurityScopedBookmark(for: pathURL))?.url ?? pathURL
            if FileManager.default.fileExists(atPath: url.path), isDirectory(url) {
                beginSecurityScopedAccess(to: url)
                rootURL = url
                workspaceTreeSession.reset(rootURL: url)
                reloadTree()
                restoreTabs()
            }
        }

    }

    var shouldHandleWindowEvents: Bool {
        guard let attachedWindow else { return true }
        return attachedWindow.isKeyWindow || attachedWindow.isMainWindow
    }

    var nativeWindow: NSWindow? {
        attachedWindow
    }

    func attach(to window: NSWindow) {
        guard attachedWindow !== window else { return }
        attachedWindow = window
        focusChrome?.stop()
        focusChrome = WindowFocusChromeSync(window: window, model: self)
    }

    func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        return values?.isRegularFile == true && values?.isDirectory != true
    }

    func isInside(_ url: URL, project: URL) -> Bool {
        let candidatePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let projectPath = project.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath == projectPath || candidatePath.hasPrefix(projectPath + "/")
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

}
