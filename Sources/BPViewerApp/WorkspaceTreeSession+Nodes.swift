import BPViewerCore
import Foundation

@MainActor
extension WorkspaceTreeSession {
    func loadChildrenIfNeeded(for path: String) {
        guard let directory = findNode(in: completeNodes, id: path),
              directory.isDirectory,
              !directory.childrenLoaded,
              let rootURL else { return }

        let generation = (childLoadGenerations[path] ?? 0) + 1
        childLoadGenerations[path] = generation
        let scanner = scanner
        let directoryURL = directory.url
        let showHiddenFiles = state.showHiddenFiles

        Task { [weak self] in
            let children = await Task.detached(priority: .userInitiated) {
                scanner.scanChildren(
                    of: directoryURL,
                    root: rootURL,
                    showHiddenFiles: showHiddenFiles
                )
            }.value

            guard let self,
                  self.childLoadGenerations[path] == generation,
                  self.rootURL?.standardizedFileURL == rootURL.standardizedFileURL else { return }

            self.updateNode(in: &self.completeNodes, id: path) { node in
                node.children = children
                node.childrenLoaded = true
            }
            self.startWatchingDirectories(rootURL: rootURL, nodes: self.completeNodes)
            self.applyTreeFilter()
            self.expandAutomaticSingleChildChainIfNeeded()
            self.loadExpandedChildrenIfNeeded()
        }
    }

    func findNode(in nodes: [FileNode], id: String) -> FileNode? {
        for node in nodes {
            if node.id == id { return node }
            if let match = findNode(in: node.children, id: id) { return match }
        }
        return nil
    }

    @discardableResult
    func updateNode(
        in nodes: inout [FileNode],
        id: String,
        update: (inout FileNode) -> Void
    ) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == id {
                update(&nodes[index])
                return true
            }
            if updateNode(in: &nodes[index].children, id: id, update: update) {
                return true
            }
        }
        return false
    }

    func mergeScannedChildren(
        _ scannedChildren: [FileNode],
        preserving existingChildren: [FileNode]
    ) -> [FileNode] {
        scannedChildren.map { scannedNode in
            guard scannedNode.isDirectory,
                  let existingNode = existingChildren.first(where: { $0.id == scannedNode.id }),
                  existingNode.childrenLoaded else {
                return scannedNode
            }

            var mergedNode = scannedNode
            mergedNode.children = existingNode.children
            mergedNode.childrenLoaded = true
            return mergedNode
        }
    }

    func updateVisibleNodes(
        from nodes: [FileNode],
        keeping visibleNodes: [FileNode],
        affectedPaths: Set<String>
    ) -> [FileNode] {
        nodes.compactMap { node in
            let oldNode = visibleNodes.first(where: { $0.id == node.id })

            if !node.isDirectory {
                guard fileKindFilter.admits(node.kind) else { return nil }
                return node
            }

            let isDirectlyAffected = affectedPaths.contains(node.relativePath)
            let hasAffectedDescendant = affectedPaths.contains { path in
                path.hasPrefix(node.relativePath + "/")
            }

            if isDirectlyAffected {
                let filteredChildren = scanner.filter(
                    node.children,
                    kindFilter: fileKindFilter,
                    query: ""
                )
                var updatedNode = node
                updatedNode.children = filteredChildren
                return updatedNode
            }

            guard hasAffectedDescendant else {
                return oldNode ?? scanner.filter(
                    [node],
                    kindFilter: fileKindFilter,
                    query: ""
                ).first
            }

            var updatedNode = oldNode ?? node
            updatedNode.children = updateVisibleNodes(
                from: node.children,
                keeping: oldNode?.children ?? [],
                affectedPaths: affectedPaths
            )
            return updatedNode
        }
    }

    func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath ? "." : String(path.dropFirst(rootPath.count + 1))
    }

    func loadExpandedChildrenIfNeeded() {
        for path in state.expandedPaths.sorted(by: { $0.count < $1.count }) {
            loadChildrenIfNeeded(for: path)
        }
    }

    func expandAutomaticSingleChildChainIfNeeded() {
        guard automaticSingleChildExpansionPending else { return }

        let candidatesForExpansion: [FileNode]
        if let basePath = automaticSingleChildExpansionBasePath {
            guard let baseNode = findNode(in: completeNodes, id: basePath) else {
                automaticSingleChildExpansionPending = false
                automaticSingleChildExpansionBasePath = nil
                return
            }
            guard baseNode.childrenLoaded else {
                loadChildrenIfNeeded(for: basePath)
                return
            }
            candidatesForExpansion = baseNode.children
        } else {
            candidatesForExpansion = completeNodes
        }

        var candidates = candidatesForExpansion
        while let directory = onlyDirectory(in: candidates) {
            if !state.expandedPaths.contains(directory.id) {
                state.expandedPaths.insert(directory.id)
                emitState()
                loadChildrenIfNeeded(for: directory.id)
                return
            }

            guard directory.childrenLoaded else {
                loadChildrenIfNeeded(for: directory.id)
                return
            }
            candidates = directory.children
        }

        automaticSingleChildExpansionPending = false
        automaticSingleChildExpansionBasePath = nil
        onPersistenceRequested()
    }

    func onlyDirectory(in nodes: [FileNode]) -> FileNode? {
        let directories = nodes.filter(\.isDirectory)
        return directories.count == 1 ? directories[0] : nil
    }
}
