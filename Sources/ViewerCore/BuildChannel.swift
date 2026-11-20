/// Which build produced the running app, read from the bundle's `ViewerBuildChannel`
/// key. Only the exact value `release` is the installed app; every other value, a
/// missing key, or no bundle at all counts as development, so the label fails towards
/// showing DEV.
public struct BuildChannel: Equatable, Sendable {
    public static let infoPlistKey = "ViewerBuildChannel"
    public static let releaseValue = "release"
    public static let labelText = "DEV"

    public let infoValue: String?

    public init(infoValue: String?) {
        self.infoValue = infoValue
    }

    /// Case-sensitive on purpose: `Release` or an empty value is not the release channel.
    public var isDevelopment: Bool {
        infoValue != Self.releaseValue
    }

    /// The window title with the DEV marker appended for development builds.
    public func windowTitle(base: String) -> String {
        isDevelopment ? "\(base) — \(Self.labelText)" : base
    }
}
