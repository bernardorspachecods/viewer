public struct WindowOpeningSize: Codable, Equatable, Sendable {
    public static let standard = Self(width: 1200, height: 780)
    public static let minimum = Self(width: 900, height: 600)

    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var meetsMinimum: Bool {
        width >= Self.minimum.width && height >= Self.minimum.height
    }

    /// The window's minimum takes precedence on displays smaller than that minimum.
    public func fitted(toWidth availableWidth: Double, height availableHeight: Double) -> (width: Double, height: Double) {
        (
            width: max(Double(Self.minimum.width), min(Double(width), availableWidth)),
            height: max(Double(Self.minimum.height), min(Double(height), availableHeight))
        )
    }
}

public struct WindowOpeningPreferences: Codable, Equatable, Sendable {
    public var remembersWorkspaceSize: Bool
    public var workspace: WindowOpeningSize
    public var reader: WindowOpeningSize

    public init(
        remembersWorkspaceSize: Bool = true,
        workspace: WindowOpeningSize = .standard,
        reader: WindowOpeningSize = .standard
    ) {
        self.remembersWorkspaceSize = remembersWorkspaceSize
        self.workspace = workspace
        self.reader = reader
    }

    public var workspaceOpeningSize: WindowOpeningSize? {
        remembersWorkspaceSize ? nil : workspace
    }
}
