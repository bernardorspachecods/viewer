import Foundation

/// Heading anchors. Heading ids and link fragments use the same key, so a link
/// written with accents or unicode letters (`#secção`, `#1-introdução`) finds the
/// heading whose id was generated from it.
public enum MarkdownAnchor {
    /// Lowercased, diacritics folded, letters, digits and marks kept, every other run becomes "-".
    /// Empty when the text has nothing to keep.
    public static func normalized(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\p{M}]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// The id base for a heading whose text is `text`.
    public static func headingBase(for text: String) -> String {
        let key = normalized(text)
        return key.isEmpty ? "section" : key
    }

    /// Ids to try, in order, for a fragment that is already percent-decoded: the
    /// fragment as written, then its normalized form.
    public static func candidates(forFragment fragment: String?) -> [String] {
        guard let fragment, !fragment.isEmpty else { return [] }
        var candidates = [fragment]
        let key = normalized(fragment)
        if !key.isEmpty, key != fragment {
            candidates.append(key)
        }
        return candidates
    }
}

/// Where a Markdown link or image destination points.
public enum MarkdownLinkTarget: Equatable, Sendable {
    /// A fragment inside the document being rendered.
    case sameDocument(anchors: [String])
    /// A local file, with the decoded fragment to show once the file is rendered.
    case localFile(URL, fragment: String?)
}

/// A scroll request for the preview: try each anchor in order, once per `id`.
public struct MarkdownAnchorRequest: Hashable, Sendable {
    public let id: UUID
    public let anchors: [String]

    public init(anchors: [String], id: UUID = UUID()) {
        self.id = id
        self.anchors = anchors
    }
}

public enum MarkdownLinkResolver {
    /// Resolves a destination as written in the Markdown source (percent-encoding
    /// and angle-bracket spaces included). Returns nil for external destinations,
    /// which have a URL scheme.
    public static func target(forDestination destination: String, baseURL: URL) -> MarkdownLinkTarget? {
        guard !destination.isEmpty else { return nil }
        if destination.hasPrefix("#") {
            let fragment = decoded(String(destination.dropFirst()))
            return .sameDocument(anchors: MarkdownAnchor.candidates(forFragment: fragment))
        }
        if URL(string: destination)?.scheme != nil {
            return nil
        }

        let parts = destination.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let path = decoded(String(parts[0]))
        let fragment = parts.count > 1 ? decoded(String(parts[1])) : nil
        let fileURL = path.hasPrefix("/")
            ? rootRelativeFileURL(path: path, baseURL: baseURL)
            : URL(fileURLWithPath: path, relativeTo: baseURL).standardizedFileURL
        return .localFile(fileURL, fragment: fragment?.isEmpty == false ? fragment : nil)
    }

    /// A destination starting with `/` (`/docs/a.md`) is read from the project root, as
    /// repositories write it, not from the disk root. A path that exists on the disk stays
    /// as written. Otherwise the project root is the nearest folder above the document with a
    /// `.git` entry; without one, or when the file is not there, the nearest folder above the
    /// document that holds the path wins. When none does, the path stays as written, so the
    /// link points at nothing.
    private static func rootRelativeFileURL(path: String, baseURL: URL) -> URL {
        let absolute = URL(fileURLWithPath: path).standardizedFileURL
        let manager = FileManager.default
        guard !manager.fileExists(atPath: absolute.path) else { return absolute }

        let relativePath = String(path.drop(while: { $0 == "/" }))
        guard !relativePath.isEmpty else { return absolute }
        let folders = foldersFrom(baseURL)

        if let gitRoot = folders.first(where: {
            manager.fileExists(atPath: $0.appendingPathComponent(".git").path)
        }) {
            let candidate = gitRoot.appendingPathComponent(relativePath).standardizedFileURL
            if manager.fileExists(atPath: candidate.path) { return candidate }
        }
        for folder in folders {
            let candidate = folder.appendingPathComponent(relativePath).standardizedFileURL
            if manager.fileExists(atPath: candidate.path) { return candidate }
        }
        return absolute
    }

    /// `url` and every folder above it, nearest first.
    private static func foldersFrom(_ url: URL) -> [URL] {
        var folders: [URL] = []
        var folder = url.standardizedFileURL
        while true {
            folders.append(folder)
            let parent = folder.deletingLastPathComponent().standardizedFileURL
            guard parent.path != folder.path else { return folders }
            folder = parent
        }
    }

    /// Anchors to scroll to when a navigation stays in the document at `documentDirectory`
    /// (a fragment on the same file). Nil when the URL is another file or has no fragment.
    public static func sameDocumentAnchors(for url: URL, documentDirectory: URL) -> [String]? {
        guard url.isFileURL,
              let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
              filePath(of: url) == filePath(of: documentDirectory) else {
            return nil
        }
        return MarkdownAnchor.candidates(forFragment: fragment)
    }

    /// The file path for comparisons: standardized, without a trailing slash.
    static func filePath(of url: URL) -> String {
        var path = url.standardizedFileURL.path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func decoded(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }
}
