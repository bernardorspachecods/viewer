import Foundation

/// Source files whose text is scanned for package and engine hints.
private let packageSourceExtensions = ["tex", "cls", "sty"]

extension LocalLatexAdapter {
    func readSyncTeXData(
        in outputDirectory: URL,
        stem: String,
        compilationProject: URL,
        project: URL
    ) -> Data? {
        let fileManager = FileManager.default
        let plainURL = outputDirectory.appendingPathComponent(stem).appendingPathExtension("synctex")
        let compressedURL = plainURL.appendingPathExtension("gz")
        let data: Data
        if let plainData = try? Data(contentsOf: plainURL) {
            data = plainData
        } else if fileManager.fileExists(atPath: compressedURL.path) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            process.arguments = ["-dc", compressedURL.path]
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                data = output
            } catch {
                return nil
            }
        } else {
            return nil
        }

        guard var source = String(data: data, encoding: .utf8) else { return nil }
        if compilationProject != project {
            source = source.replacingOccurrences(of: compilationProject.path, with: project.path)
        }
        return Data(source.utf8)
    }

    func copyProjectInputs(
        _ inputs: [URL],
        projectRoot: URL,
        overlayRoot: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: overlayRoot, withIntermediateDirectories: true)
        var inputURLs = Set(inputs.map(\.standardizedFileURL))
        for configurationName in [".latexmkrc", "latexmkrc"] {
            let configurationURL = projectRoot.appendingPathComponent(configurationName)
            if isRegularFile(configurationURL) {
                inputURLs.insert(configurationURL.standardizedFileURL)
            }
        }

        for item in inputURLs {
            var fileStatus = stat()
            guard lstat(item.path, &fileStatus) == 0 else { continue }
            guard isInside(item, project: projectRoot) else { continue }
            let target = overlayRoot.appendingPathComponent(
                relativePath(of: item, within: projectRoot)
            )
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            switch fileStatus.st_mode & S_IFMT {
            case S_IFREG, S_IFLNK:
                try fileManager.copyItem(at: item, to: target)
            default:
                // Unix sockets, FIFOs and device files are runtime state, not
                // LaTeX project inputs, and cannot be copied into an overlay.
                continue
            }
        }
    }

    func searchEnvironment(
        root: URL,
        project: URL,
        dependencies: [URL]
    ) -> [String: String] {
        var directories = Set<URL>([
            project.standardizedFileURL,
            root.deletingLastPathComponent().standardizedFileURL
        ])
        directories.formUnion(
            dependencies.map { $0.deletingLastPathComponent().standardizedFileURL }
        )

        let searchPath = directories
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            .map(\.path)
            .joined(separator: ":") + ":"
        return [
            // Keep all project paths non-recursive. A broad user-selected
            // root must not make kpathsea traverse protected folders; local
            // dependency directories are already represented in `directories`.
            "TEXINPUTS": searchPath,
            "BIBINPUTS": searchPath,
            "BSTINPUTS": searchPath
        ]
    }

    func dependencies(
        for root: URL,
        project: URL,
        sourceOverrides: [URL: String] = [:]
    ) -> [URL] {
        var discovered = Set([root.standardizedFileURL])
        var pending = [root.standardizedFileURL]

        while let current = pending.popLast() {
            guard let source = source(for: current, overrides: sourceOverrides) else { continue }
            for reference in referencedPaths(in: source) {
                guard let dependency = resolve(reference: reference, relativeTo: current, project: project),
                      discovered.insert(dependency).inserted else { continue }
                pending.append(dependency)
            }
        }

        return discovered.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    var shellEscapeArgument: String {
        switch shellEscapeMode {
        case .disabled:
            "-no-shell-escape"
        case .restricted:
            "-shell-restricted"
        case .enabled:
            "-shell-escape"
        }
    }

    func dependenciesFromRecorder(
        at recorderURL: URL,
        project: URL,
        overlayProject: URL? = nil
    ) -> [URL] {
        guard let recorder = try? String(contentsOf: recorderURL, encoding: .utf8) else {
            return []
        }

        var workingDirectory = recorderURL.deletingLastPathComponent()
        var discovered = Set<URL>()

        for line in recorder.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("PWD ") {
                let path = String(line.dropFirst(4))
                workingDirectory = URL(fileURLWithPath: path).standardizedFileURL
                continue
            }
            guard line.hasPrefix("INPUT ") else { continue }

            let path = String(line.dropFirst(6))
            let recordedURL = (path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path))
                .standardizedFileURL
            let inputURL: URL
            if let overlayProject,
               isInside(recordedURL, project: overlayProject) {
                inputURL = project.appendingPathComponent(
                    relativePath(of: recordedURL, within: overlayProject)
                ).standardizedFileURL
            } else {
                inputURL = recordedURL
            }
            guard isRegularFile(inputURL), isInside(inputURL, project: project) else { continue }
            discovered.insert(inputURL)
        }

        return discovered.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    enum BibliographyTool: String {
        case biber
        case bibtex
    }

    func bibliographyTool(for dependencies: [URL]) -> BibliographyTool? {
        var usesBibLaTeX = false
        var usesBibTeX = false

        for dependency in dependencies where packageSourceExtensions.contains(dependency.pathExtension.lowercased()) {
            guard let source = try? String(contentsOf: dependency, encoding: .utf8) else { continue }
            if source.range(of: #"\\(?:usepackage|RequirePackage)(?:\[[^\]]*\])?\s*\{\s*biblatex\s*\}"#, options: .regularExpression) != nil
                || source.range(of: #"\\addbibresource\s*\{"#, options: .regularExpression) != nil {
                usesBibLaTeX = true
            }
            if source.range(of: #"\\bibliography\s*\{"#, options: .regularExpression) != nil {
                usesBibTeX = true
            }
        }

        if usesBibLaTeX { return .biber }
        if usesBibTeX { return .bibtex }
        return nil
    }

    func engineHint(for dependencies: [URL]) -> LatexCompilerKind? {
        var usesLua = false
        var usesSystemFonts = false

        for dependency in dependencies where packageSourceExtensions.contains(dependency.pathExtension.lowercased()) {
            guard let source = try? String(contentsOf: dependency, encoding: .utf8) else { continue }
            if source.range(of: #"\\(?:usepackage|RequirePackage)(?:\[[^\]]*\])?\s*\{\s*luatexja\s*\}"#, options: .regularExpression) != nil
                || source.range(of: #"\\directlua\b"#, options: .regularExpression) != nil {
                usesLua = true
            }
            if source.range(of: #"\\(?:usepackage|RequirePackage)(?:\[[^\]]*\])?\s*\{\s*fontspec\s*\}"#, options: .regularExpression) != nil
                || source.range(of: #"\\(?:setmainfont|setsansfont|setmonofont)\b"#, options: .regularExpression) != nil {
                usesSystemFonts = true
            }
        }

        if usesLua { return .lualatex }
        if usesSystemFonts { return .xelatex }
        return nil
    }

    func source(for url: URL, overrides: [URL: String]) -> String? {
        if let override = overrides[url.standardizedFileURL] {
            return override
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func writeSourceOverrides(
        _ overrides: [URL: String],
        projectRoot: URL,
        overlayRoot: URL
    ) throws {
        for (sourceURL, source) in overrides {
            guard isRegularFile(sourceURL), isInside(sourceURL, project: projectRoot) else {
                continue
            }
            let destination = overlayRoot.appendingPathComponent(
                relativePath(of: sourceURL, within: projectRoot)
            )
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try source.write(to: destination, atomically: true, encoding: .utf8)
        }
    }

    func relativePath(of url: URL, within root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        guard urlPath.hasPrefix(rootPath + "/") else { return url.lastPathComponent }
        return String(urlPath.dropFirst(rootPath.count + 1))
    }

    func combinedResult(_ results: [ProcessResult]) -> ProcessResult {
        let failed = results.first { $0.status != .success }
        return ProcessResult(
            status: failed?.status ?? .success,
            exitCode: failed?.exitCode ?? results.last?.exitCode,
            standardOutput: results.map(\.standardOutput).filter { !$0.isEmpty }.joined(separator: "\n"),
            standardError: results.map(\.standardError).filter { !$0.isEmpty }.joined(separator: "\n"),
            duration: results.reduce(0) { $0 + $1.duration }
        )
    }

    func referencedPaths(in source: String) -> [String] {
        let pattern = #"\\(?:input|include|subfile|addbibresource|bibliography|bibliographystyle|includegraphics|documentclass|usepackage|RequirePackage|setmainfont|setsansfont|setmonofont|newfontfamily)(?:\[[^\]]*\])?\s*\{([^}]+)\}"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: (source as NSString).length)
        return expression.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return (source as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func resolve(reference: String, relativeTo source: URL, project: URL) -> URL? {
        return candidateURLs(reference: reference, relativeTo: source)
            .map(\.standardizedFileURL)
            .first { url in
                isRegularFile(url) && isInside(url, project: project)
            }
    }

    func candidateURLs(reference: String, relativeTo source: URL) -> [URL] {
        let baseURL = reference.hasPrefix("/")
            ? URL(fileURLWithPath: reference)
            : source.deletingLastPathComponent().appendingPathComponent(reference)
        return [
            baseURL,
            baseURL.appendingPathExtension("tex"),
            baseURL.appendingPathExtension("bib"),
            baseURL.appendingPathExtension("bst"),
            baseURL.appendingPathExtension("cls"),
            baseURL.appendingPathExtension("sty"),
            baseURL.appendingPathExtension("png"),
            baseURL.appendingPathExtension("jpg"),
            baseURL.appendingPathExtension("jpeg"),
            baseURL.appendingPathExtension("pdf"),
            baseURL.appendingPathExtension("eps"),
            baseURL.appendingPathExtension("svg"),
            baseURL.appendingPathExtension("ttf"),
            baseURL.appendingPathExtension("otf"),
            baseURL.appendingPathExtension("woff"),
            baseURL.appendingPathExtension("woff2")
        ]
    }

    func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    func isRegularFile(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) && !isDirectory(url)
    }

    func isInside(_ url: URL, project: URL) -> Bool {
        let candidatePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let projectPath = project.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath == projectPath || candidatePath.hasPrefix(projectPath + "/")
    }

}
