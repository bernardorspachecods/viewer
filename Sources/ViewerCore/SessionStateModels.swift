import Foundation

public struct AppState: Codable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion = Self.currentSchemaVersion
    public var global = GlobalState()
    public var documentStates: [String: DocumentState] = [:]
    public var workspaceStates: [String: WorkspaceState] = [:]
    public var lastWorkspacePath: String?
    public var openWorkspacePaths: [String] = []
    public var activeWorkspacePath: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, global, documentStates, workspaceStates, lastWorkspacePath
        case openWorkspacePaths, activeWorkspacePath
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        global = try container.decodeIfPresent(GlobalState.self, forKey: .global) ?? GlobalState()
        documentStates = try container.decodeIfPresent([String: DocumentState].self, forKey: .documentStates) ?? [:]
        workspaceStates = try container.decodeIfPresent([String: WorkspaceState].self, forKey: .workspaceStates) ?? [:]
        lastWorkspacePath = try container.decodeIfPresent(String.self, forKey: .lastWorkspacePath)
        openWorkspacePaths = try container.decodeIfPresent([String].self, forKey: .openWorkspacePaths) ?? []
        activeWorkspacePath = try container.decodeIfPresent(String.self, forKey: .activeWorkspacePath)
    }
}

/// Pure list rules for the default workspace folders, kept separate from
/// persistence so they can be checked without UserDefaults or a window.
public enum DefaultWorkspaceFolders {
    /// Appends `path` unless it is already listed, keeping the existing order.
    public static func adding(_ path: String, to paths: [String]) -> [String] {
        paths.contains(path) ? paths : paths + [path]
    }

    public static func removing(_ path: String, from paths: [String]) -> [String] {
        paths.filter { $0 != path }
    }

    /// Drops repeated paths, keeping the first occurrence of each.
    public static func deduplicated(_ paths: [String]) -> [String] {
        paths.reduce(into: [String]()) { result, path in
            result = adding(path, to: result)
        }
    }
}

public struct GlobalState: Codable, Sendable {
    public var theme = "dark"
    public var sidebarVisible = true
    public var sidebarWidth = 280.0
    public var latexShellEscapeMode = "disabled"
    public var defaultMarkdownZoom = 1.0
    public var defaultLatexZoom = 1.0
    /// Opened when the previous session cannot be restored; empty means the home folder.
    public var defaultWorkspaceFolders: [String] = []
    /// Raw value of `LaunchBehavior`; absent in older state, which reopens the last session.
    public var launchBehavior = LaunchBehavior.reopenLast.rawValue
    /// Raw values of the `DocumentKind`s shown by "Show selected files only".
    public var selectedFileKinds: [String] = DocumentKind.selectableKinds.map(\.rawValue)
    /// Extra extensions shown by "Show selected files only", for files the app does not support.
    public var extraFileExtensions: [String] = []

    private enum CodingKeys: String, CodingKey {
        case theme, sidebarVisible, sidebarWidth, latexShellEscapeMode
        case defaultMarkdownZoom, defaultLatexZoom, defaultWorkspaceFolders, selectedFileKinds
        case extraFileExtensions, launchBehavior
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "dark"
        sidebarVisible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) ?? true
        sidebarWidth = try container.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? 280
        latexShellEscapeMode = try container.decodeIfPresent(String.self, forKey: .latexShellEscapeMode) ?? "disabled"
        defaultMarkdownZoom = try container.decodeIfPresent(Double.self, forKey: .defaultMarkdownZoom) ?? 1.0
        defaultLatexZoom = try container.decodeIfPresent(Double.self, forKey: .defaultLatexZoom) ?? 1.0
        defaultWorkspaceFolders = try container.decodeIfPresent([String].self, forKey: .defaultWorkspaceFolders) ?? []
        launchBehavior = try container.decodeIfPresent(String.self, forKey: .launchBehavior)
            ?? LaunchBehavior.reopenLast.rawValue
        selectedFileKinds = try container.decodeIfPresent([String].self, forKey: .selectedFileKinds)
            ?? DocumentKind.selectableKinds.map(\.rawValue)
        extraFileExtensions = try container.decodeIfPresent([String].self, forKey: .extraFileExtensions) ?? []
    }
}

public struct DocumentState: Codable, Sendable {
    public var zoom: Double?
    public var outlineVisible: Bool
    public var outlineWidth: Double
    public var markdownReadingPosition: MarkdownReadingPosition?
    public var pdfReadingPosition: PDFReadingPosition?

    private enum CodingKeys: String, CodingKey {
        case zoom, outlineVisible, outlineWidth, markdownReadingPosition, pdfReadingPosition
    }

    public init(
        zoom: Double? = nil,
        outlineVisible: Bool = false,
        outlineWidth: Double = DocumentOutlineSizing.defaultWidth,
        markdownReadingPosition: MarkdownReadingPosition? = nil,
        pdfReadingPosition: PDFReadingPosition? = nil
    ) {
        self.zoom = zoom
        self.outlineVisible = outlineVisible
        self.outlineWidth = DocumentOutlineSizing.clamped(outlineWidth)
        self.markdownReadingPosition = markdownReadingPosition
        self.pdfReadingPosition = pdfReadingPosition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1.0
        outlineVisible = try container.decodeIfPresent(Bool.self, forKey: .outlineVisible) ?? false
        outlineWidth = DocumentOutlineSizing.clamped(
            try container.decodeIfPresent(Double.self, forKey: .outlineWidth)
                ?? DocumentOutlineSizing.defaultWidth
        )
        markdownReadingPosition = try container.decodeIfPresent(MarkdownReadingPosition.self, forKey: .markdownReadingPosition)
        pdfReadingPosition = try container.decodeIfPresent(PDFReadingPosition.self, forKey: .pdfReadingPosition)
    }
}

public struct SnapshotRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let documentPath: String
    public let title: String
    public let artifactPath: String
    public let createdAt: Date

    public init(id: String, documentPath: String, title: String, artifactPath: String, createdAt: Date) {
        self.id = id
        self.documentPath = documentPath
        self.title = title
        self.artifactPath = artifactPath
        self.createdAt = createdAt
    }
}

public struct WorkspaceState: Codable, Sendable {
    public var tabPaths: [String] = []
    public var activeTabPath: String?
    public var tabContexts: [String: String] = [:]
    public var expandedPaths: [String] = []
    /// The workspace root's listing is hidden. Absent in older state, which
    /// therefore opens with the root shown.
    public var isRootCollapsed = false
    public var treeScrollOffset = 0.0
    /// Persisted under the original `compatibleOnly` key, so older state still loads.
    public var showSelectedFilesOnly = true
    public var showHiddenFiles = false
    public var latexRootSelections: [String: String] = [:]
    public var latexExternalGrants: [String: [String]] = [:]
    public var securityScopedBookmark: Data?
    public var snapshots: [SnapshotRecord] = []

    private enum CodingKeys: String, CodingKey {
        case tabPaths, activeTabPath, tabContexts, expandedPaths
        case isRootCollapsed = "rootCollapsed"
        case treeScrollOffset
        case showSelectedFilesOnly = "compatibleOnly"
        case showHiddenFiles, latexRootSelections, latexExternalGrants, securityScopedBookmark, snapshots
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tabPaths = try container.decodeIfPresent([String].self, forKey: .tabPaths) ?? []
        activeTabPath = try container.decodeIfPresent(String.self, forKey: .activeTabPath)
        tabContexts = try container.decodeIfPresent([String: String].self, forKey: .tabContexts) ?? [:]
        expandedPaths = try container.decodeIfPresent([String].self, forKey: .expandedPaths) ?? []
        isRootCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isRootCollapsed) ?? false
        treeScrollOffset = try container.decodeIfPresent(Double.self, forKey: .treeScrollOffset) ?? 0
        showSelectedFilesOnly = try container.decodeIfPresent(Bool.self, forKey: .showSelectedFilesOnly) ?? true
        showHiddenFiles = try container.decodeIfPresent(Bool.self, forKey: .showHiddenFiles) ?? false
        latexRootSelections = try container.decodeIfPresent([String: String].self, forKey: .latexRootSelections) ?? [:]
        latexExternalGrants = try container.decodeIfPresent([String: [String]].self, forKey: .latexExternalGrants) ?? [:]
        securityScopedBookmark = try container.decodeIfPresent(Data.self, forKey: .securityScopedBookmark)
        snapshots = try container.decodeIfPresent([SnapshotRecord].self, forKey: .snapshots) ?? []
    }
}

public struct AppStateStore {
    private static let defaultsKey = "viewer.appState"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppState {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState()
        }
        return state
    }

    public func save(_ state: AppState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
