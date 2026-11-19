import Foundation

public struct LatexExecutableLocator: Sendable {
    private let injectedCandidates: [URL]?

    public init(candidateURLs: [URL]? = nil) {
        injectedCandidates = candidateURLs?.map(\.standardizedFileURL)
    }

    public func findTool(named name: String) -> URL? {
        let candidates = injectedCandidates ?? [
            URL(fileURLWithPath: "/Library/TeX/texbin/\(name)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
            URL(fileURLWithPath: "/usr/bin/\(name)")
        ]
        return candidates
            .filter { $0.lastPathComponent == name }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public func findCompiler(preferredKind: LatexCompilerKind? = nil) -> LatexCompiler? {
        let candidates: [(String, LatexCompilerKind)] = injectedCandidates?.compactMap { url in
            guard let kind = LatexCompilerKind(rawValue: url.lastPathComponent.lowercased()) else {
                return nil
            }
            return (url.path, kind)
        } ?? [
            ("/Library/TeX/texbin/latexmk", .latexmk),
            ("/opt/homebrew/bin/latexmk", .latexmk),
            ("/usr/local/bin/latexmk", .latexmk),
            ("/usr/bin/latexmk", .latexmk),
            ("/Library/TeX/texbin/pdflatex", .pdflatex),
            ("/opt/homebrew/bin/pdflatex", .pdflatex),
            ("/usr/local/bin/pdflatex", .pdflatex),
            ("/usr/bin/pdflatex", .pdflatex),
            ("/Library/TeX/texbin/xelatex", .xelatex),
            ("/opt/homebrew/bin/xelatex", .xelatex),
            ("/usr/local/bin/xelatex", .xelatex),
            ("/usr/bin/xelatex", .xelatex),
            ("/Library/TeX/texbin/lualatex", .lualatex),
            ("/opt/homebrew/bin/lualatex", .lualatex),
            ("/usr/local/bin/lualatex", .lualatex),
            ("/usr/bin/lualatex", .lualatex)
        ]
        let orderedCandidates: [(String, LatexCompilerKind)]
        if let preferredKind {
            let latexmkCandidates = candidates.filter { $0.1 == .latexmk }
            let preferredCandidates = candidates.filter { $0.1 == preferredKind && $0.1 != .latexmk }
            let remainingCandidates = candidates.filter {
                $0.1 != .latexmk && $0.1 != preferredKind
            }
            orderedCandidates = latexmkCandidates + preferredCandidates + remainingCandidates
        } else {
            orderedCandidates = candidates
        }
        let candidatesToProbe: [(String, LatexCompilerKind)]
        if preferredKind == .xelatex || preferredKind == .lualatex {
            // A document that requires a specialised engine must not silently
            // fall back to pdfLaTeX. latexmk remains a valid wrapper because
            // it is invoked with the corresponding engine flag above.
            candidatesToProbe = orderedCandidates.filter {
                $0.1 == .latexmk || $0.1 == preferredKind
            }
        } else {
            candidatesToProbe = orderedCandidates
        }

        return candidatesToProbe
            .map { LatexCompiler(url: URL(fileURLWithPath: $0.0), kind: $0.1) }
            .first { FileManager.default.isExecutableFile(atPath: $0.url.path) }
    }
}

public enum LatexCompilerKind: String, Sendable {
    case latexmk
    case pdflatex
    case xelatex
    case lualatex
}

public enum LatexShellEscapeMode: String, CaseIterable, Codable, Sendable {
    case disabled
    case restricted
    case enabled

    public var label: String {
        switch self {
        case .disabled: "Disabled"
        case .restricted: "Restricted"
        case .enabled: "Enabled"
        }
    }
}

public struct LatexCompiler: Sendable {
    public let url: URL
    public let kind: LatexCompilerKind

    public init(url: URL, kind: LatexCompilerKind) {
        self.url = url.standardizedFileURL
        self.kind = kind
    }
}
