import BPViewerCore
import Darwin
import Foundation

@MainActor
extension WorkspaceTreeSession {
    func startWatchingDirectories(rootURL: URL, nodes: [FileNode]) {
        var directories = Set([rootURL.standardizedFileURL])
        collectDirectories(from: nodes, into: &directories)
        guard directories != watchedDirectoryURLs else { return }

        stopWatchingDirectories()
        for url in directories {
            let descriptor = Darwin.open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .link],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.scheduleTreeRefresh(for: url)
            }
            source.setCancelHandler {
                Darwin.close(descriptor)
            }
            activeDirectoryWatchers[url] = source
            watchedDirectoryURLs.insert(url)
            source.resume()
        }
    }

    func collectDirectories(from nodes: [FileNode], into directories: inout Set<URL>) {
        for node in nodes where node.isDirectory {
            guard node.childrenLoaded else { continue }
            directories.insert(node.url.standardizedFileURL)
            collectDirectories(from: node.children, into: &directories)
        }
    }

    func stopWatchingDirectories() {
        activeDirectoryWatchers.values.forEach { $0.cancel() }
        activeDirectoryWatchers.removeAll()
        watchedDirectoryURLs.removeAll()
        treeRefreshGeneration += 1
    }

    func scheduleTreeRefresh(for directoryURL: URL) {
        guard watchedDirectoryURLs.contains(directoryURL.standardizedFileURL) else { return }
        if let suppressedUntil = watcherRefreshSuppressedUntil {
            guard Date() >= suppressedUntil else { return }
            watcherRefreshSuppressedUntil = nil
        }

        treeRefreshGeneration += 1
        let generation = treeRefreshGeneration
        let rootURL = rootURL
        let knownStructure = childStructureSignature(in: directoryURL, rootURL: rootURL)
        let scanner = scanner
        let showHiddenFiles = state.showHiddenFiles
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.treeRefreshGeneration == generation,
                  let rootURL else { return }

            let currentStructure = await Task.detached(priority: .userInitiated) {
                Set(
                    scanner.scanChildren(
                        of: directoryURL,
                        root: rootURL,
                        showHiddenFiles: showHiddenFiles
                    )
                        .map { "\($0.id)|\($0.isDirectory ? "directory" : "file")" }
                )
            }.value

            guard self.treeRefreshGeneration == generation,
                  currentStructure != knownStructure else { return }

            let refreshDirectory = FileManager.default.fileExists(atPath: directoryURL.path)
                ? directoryURL
                : directoryURL.deletingLastPathComponent()
            self.refreshAfterFileOperation(in: [refreshDirectory])
        }
    }

    func childStructureSignature(in directoryURL: URL, rootURL: URL?) -> Set<String> {
        guard let rootURL else { return [] }
        let children: [FileNode]
        if directoryURL.standardizedFileURL == rootURL.standardizedFileURL {
            children = completeNodes
        } else {
            children = findNode(
                in: completeNodes,
                id: relativePath(of: directoryURL, from: rootURL)
            )?.children ?? []
        }
        return Set(children.map { "\($0.id)|\($0.isDirectory ? "directory" : "file")" })
    }
}
