import BPViewerCore
import Darwin
import Foundation

/// Owns the asynchronous workspace tree lifecycle independently of the UI
/// session. The app observes snapshots and decides when workspace state is
/// persisted.
@MainActor
final class WorkspaceTreeSession {
    private static let periodicRefreshInterval: Duration = .seconds(30)

    struct State: Equatable {
        var nodes: [FileNode] = []
        var expandedPaths: Set<String> = []
        var treeScrollOffset = 0.0
        var showSelectedFilesOnly = true
        var selectedFileKinds = Set(DocumentKind.selectableKinds)
        var showHiddenFiles = false
        var isScanning = false
        var isFiltering = false
    }

    let scanner: FileSystemScanner
    private let onStateChange: (State) -> Void
    let onPersistenceRequested: () -> Void
    var state = State()
    var rootURL: URL?
    var completeNodes: [FileNode] = []
    private var treeScanGeneration = 0
    private var treeFilterGeneration = 0
    private var treeFilterTask: Task<Void, Never>?
    private var treeScrollPersistenceTask: Task<Void, Never>?
    private var periodicRefreshTask: Task<Void, Never>?
    var automaticSingleChildExpansionPending = false
    var automaticSingleChildExpansionBasePath: String?
    var childLoadGenerations: [String: Int] = [:]
    var activeDirectoryWatchers: [URL: DispatchSourceFileSystemObject] = [:]
    var watchedDirectoryURLs: Set<URL> = []
    var treeRefreshGeneration = 0
    var watcherRefreshSuppressedUntil: Date?

    init(
        scanner: FileSystemScanner = FileSystemScanner(),
        onStateChange: @escaping (State) -> Void,
        onPersistenceRequested: @escaping () -> Void
    ) {
        self.scanner = scanner
        self.onStateChange = onStateChange
        self.onPersistenceRequested = onPersistenceRequested
    }

    var snapshot: State { state }

    func reset(rootURL: URL?) {
        stop()
        self.rootURL = rootURL?.standardizedFileURL
        completeNodes = []
        childLoadGenerations.removeAll()
        automaticSingleChildExpansionPending = false
        automaticSingleChildExpansionBasePath = nil
        state.nodes = []
        state.expandedPaths = []
        state.treeScrollOffset = 0
        state.isScanning = false
        state.isFiltering = false
        emitState()

        if let rootURL = self.rootURL {
            startWatchingDirectories(rootURL: rootURL, nodes: [])
            startPeriodicRefresh()
        }
    }

    func restore(
        expandedPaths: Set<String>,
        treeScrollOffset: Double,
        showSelectedFilesOnly: Bool,
        selectedFileKinds: Set<DocumentKind>,
        showHiddenFiles: Bool,
        automaticSingleChildExpansion: Bool
    ) {
        state.expandedPaths = expandedPaths
        state.treeScrollOffset = max(treeScrollOffset, 0)
        state.showSelectedFilesOnly = showSelectedFilesOnly
        state.selectedFileKinds = selectedFileKinds
        state.showHiddenFiles = showHiddenFiles
        automaticSingleChildExpansionPending = automaticSingleChildExpansion
        automaticSingleChildExpansionBasePath = nil
        emitState()
    }

    func reload() {
        guard let rootURL else {
            completeNodes = []
            state.nodes = []
            state.isScanning = false
            emitState()
            return
        }

        // A file operation can already have triggered a watcher refresh. The
        // explicit reload is authoritative, so invalidate that pending work
        // instead of scanning the tree a second time shortly afterwards.
        treeRefreshGeneration += 1
        treeScanGeneration += 1
        let generation = treeScanGeneration
        let scanner = scanner
        let showHiddenFiles = state.showHiddenFiles
        let expandedPaths = state.expandedPaths.sorted {
            $0.split(separator: "/").count < $1.split(separator: "/").count
        }
        childLoadGenerations.removeAll()
        state.isScanning = true
        emitState()

        Task { [weak self] in
            let scanResult = await Task.detached(priority: .userInitiated) {
                let topLevel = scanner.scanTopLevel(root: rootURL, showHiddenFiles: showHiddenFiles)
                let expandedDirectories = expandedPaths.reduce(into: [String: [FileNode]]()) { result, path in
                    let directoryURL = rootURL.appendingPathComponent(path).standardizedFileURL
                    result[path] = scanner.scanChildren(
                        of: directoryURL,
                        root: rootURL,
                        showHiddenFiles: showHiddenFiles
                    )
                }
                return (topLevel, expandedDirectories)
            }.value

            guard let self,
                  self.treeScanGeneration == generation,
                  self.rootURL?.standardizedFileURL == rootURL.standardizedFileURL else { return }

            var refreshedNodes = self.mergeScannedChildren(
                scanResult.0,
                preserving: self.completeNodes
            )
            for path in expandedPaths {
                guard let scannedChildren = scanResult.1[path] else { continue }
                self.updateNode(in: &refreshedNodes, id: path) { node in
                    node.children = self.mergeScannedChildren(
                        scannedChildren,
                        preserving: node.children
                    )
                    node.childrenLoaded = true
                }
            }

            self.completeNodes = refreshedNodes
            self.state.isScanning = false
            self.startWatchingDirectories(rootURL: rootURL, nodes: refreshedNodes)
            self.applyTreeFilter()
            self.expandAutomaticSingleChildChainIfNeeded()
            self.loadExpandedChildrenIfNeeded()
        }
    }

    func refreshAfterFileOperation(in directories: [URL]) {
        guard let rootURL else { return }

        // File-system notifications for a local operation can arrive after
        // the explicit refresh. Ignore that short burst so one action cannot
        // enqueue a second update while SwiftUI is laying out rows.
        watcherRefreshSuppressedUntil = Date().addingTimeInterval(0.75)
        let directories = Set(directories.map { $0.standardizedFileURL })
        guard !directories.isEmpty else { return }

        treeRefreshGeneration += 1
        treeScanGeneration += 1
        let generation = treeScanGeneration
        let scanner = scanner
        let showHiddenFiles = state.showHiddenFiles
        treeFilterGeneration += 1
        treeFilterTask?.cancel()
        treeFilterTask = nil
        state.isFiltering = false
        state.isScanning = false

        for directory in directories {
            let path = relativePath(of: directory, from: rootURL)
            childLoadGenerations[path] = (childLoadGenerations[path] ?? 0) + 1
        }

        Task { [weak self] in
            let scannedDirectories = await Task.detached(priority: .userInitiated) {
                directories.reduce(into: [URL: [FileNode]]()) { result, directory in
                    result[directory] = scanner.scanChildren(
                        of: directory,
                        root: rootURL,
                        showHiddenFiles: showHiddenFiles
                    )
                }
            }.value

            guard let self,
                  self.treeScanGeneration == generation,
                  self.rootURL?.standardizedFileURL == rootURL.standardizedFileURL else { return }

            for directory in directories {
                guard let scannedChildren = scannedDirectories[directory] else { continue }
                let existingChildren: [FileNode]
                if directory == rootURL.standardizedFileURL {
                    existingChildren = self.completeNodes
                } else {
                    existingChildren = self.findNode(
                        in: self.completeNodes,
                        id: self.relativePath(of: directory, from: rootURL)
                    )?.children ?? []
                }
                let mergedChildren = self.mergeScannedChildren(
                    scannedChildren,
                    preserving: existingChildren
                )

                if directory == rootURL.standardizedFileURL {
                    self.completeNodes = mergedChildren
                } else {
                    self.updateNode(
                        in: &self.completeNodes,
                        id: self.relativePath(of: directory, from: rootURL)
                    ) { node in
                        node.children = mergedChildren
                        node.childrenLoaded = true
                    }
                }
            }

            let affectedPaths = Set(directories.map {
                self.relativePath(of: $0, from: rootURL)
            })
            self.state.nodes = self.updateVisibleNodes(
                from: self.completeNodes,
                keeping: self.state.nodes,
                affectedPaths: affectedPaths
            )
            self.startWatchingDirectories(rootURL: rootURL, nodes: self.completeNodes)
            self.loadExpandedChildrenIfNeeded()
            self.emitState()
        }
    }

    func setShowSelectedFilesOnly(_ value: Bool) {
        state.showSelectedFilesOnly = value
        emitState()
        applyTreeFilter()
    }

    func setSelectedFileKinds(_ kinds: Set<DocumentKind>) {
        state.selectedFileKinds = kinds
        emitState()
        applyTreeFilter()
    }

    func setShowHiddenFiles(_ value: Bool) {
        guard state.showHiddenFiles != value else { return }
        state.showHiddenFiles = value
        completeNodes = []
        state.nodes = []
        emitState()
        reload()
    }

    func toggleExpanded(_ path: String) {
        automaticSingleChildExpansionPending = false
        automaticSingleChildExpansionBasePath = nil
        if state.expandedPaths.contains(path) {
            state.expandedPaths.remove(path)
        } else {
            state.expandedPaths.insert(path)
            automaticSingleChildExpansionPending = true
            automaticSingleChildExpansionBasePath = path
            if findNode(in: completeNodes, id: path)?.childrenLoaded == true {
                expandAutomaticSingleChildChainIfNeeded()
            } else {
                loadChildrenIfNeeded(for: path)
            }
        }
        emitState()
    }

    func reveal(url: URL) {
        guard let rootURL else { return }

        let rootPath = rootURL.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else { return }

        let relativePath = relativePath(of: url, from: rootURL)
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }

        automaticSingleChildExpansionPending = false
        automaticSingleChildExpansionBasePath = nil

        var ancestorPath = ""
        for component in components.dropLast() {
            ancestorPath = ancestorPath.isEmpty
                ? component
                : ancestorPath + "/" + component
            state.expandedPaths.insert(ancestorPath)
        }

        emitState()
        loadExpandedChildrenIfNeeded()
    }

    func collapseAllFolders() {
        state.expandedPaths.removeAll()
        automaticSingleChildExpansionPending = false
        automaticSingleChildExpansionBasePath = nil
        childLoadGenerations.removeAll()
        emitState()
    }

    func collapseFolder(_ path: String) {
        let prefix = path + "/"
        state.expandedPaths = state.expandedPaths.filter {
            $0 != path && !$0.hasPrefix(prefix)
        }
        if automaticSingleChildExpansionBasePath == path
            || automaticSingleChildExpansionBasePath?.hasPrefix(prefix) == true {
            automaticSingleChildExpansionPending = false
            automaticSingleChildExpansionBasePath = nil
        }
        childLoadGenerations = childLoadGenerations.filter { key, _ in
            key != path && !key.hasPrefix(prefix)
        }
        emitState()
    }

    func relocateExpandedPaths(from oldPath: String, to newPath: String) {
        guard oldPath != newPath else { return }
        state.expandedPaths = Set(state.expandedPaths.map { path in
            guard path == oldPath || path.hasPrefix(oldPath + "/") else { return path }
            return newPath + String(path.dropFirst(oldPath.count))
        })
        emitState()
    }

    func updateScrollOffset(_ offset: Double) {
        let normalizedOffset = max(offset, 0)
        guard abs(state.treeScrollOffset - normalizedOffset) > 0.5 else { return }
        state.treeScrollOffset = normalizedOffset
        emitState()
        treeScrollPersistenceTask?.cancel()
        treeScrollPersistenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.onPersistenceRequested()
        }
    }

    func stop() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
        treeFilterTask?.cancel()
        treeFilterTask = nil
        treeScrollPersistenceTask?.cancel()
        treeScrollPersistenceTask = nil
        stopWatchingDirectories()
        watcherRefreshSuppressedUntil = nil
        treeScanGeneration += 1
        childLoadGenerations.removeAll()
    }

    private func startPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.periodicRefreshInterval)
                } catch {
                    return
                }

                guard let self else { return }
                guard self.rootURL != nil,
                      !self.state.isScanning,
                      !self.state.isFiltering else { continue }

                self.reload()
            }
        }
    }

    func emitState() {
        onStateChange(state)
    }

    var fileKindFilter: FileKindFilter {
        FileKindFilter(
            showsOnlySelectedKinds: state.showSelectedFilesOnly,
            selectedKinds: state.selectedFileKinds
        )
    }

    func applyTreeFilter() {
        treeFilterGeneration += 1
        let generation = treeFilterGeneration
        let scanner = scanner
        let completeNodes = completeNodes
        let kindFilter = fileKindFilter

        treeFilterTask?.cancel()
        state.isFiltering = true
        emitState()
        treeFilterTask = Task { [weak self] in
            let filteredNodes = await Task.detached(priority: .userInitiated) {
                scanner.filter(completeNodes, kindFilter: kindFilter, query: "")
            }.value

            guard let self,
                  self.treeFilterGeneration == generation,
                  self.rootURL != nil else { return }

            self.state.nodes = filteredNodes
            self.state.isFiltering = false
            self.emitState()
        }
    }

}
