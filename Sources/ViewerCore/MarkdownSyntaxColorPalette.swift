import Foundation

public struct MarkdownSyntaxColorPalette: Equatable, Sendable {
    public let background: String
    public let foreground: String
    public let heading: String
    public let emphasis: String
    public let strong: String
    public let strikethrough: String
    public let code: String
    public let linkText: String
    public let linkDestination: String
    public let listMarker: String
    public let quoteMarker: String
    public let thematicBreak: String
    public let html: String
    public let frontMatter: String

    public init(isDark: Bool) {
        self = isDark ? .dark : .light
    }

    public static let light = Self(
        background: "#FFFFFF",
        foreground: "#1F1F1F",
        heading: "#005CC5",
        emphasis: "#005CC5",
        strong: "#005CC5",
        strikethrough: "#A31515",
        code: "#005CC5",
        linkText: "#005CC5",
        linkDestination: "#A31515",
        listMarker: "#6A737D",
        quoteMarker: "#6A737D",
        thematicBreak: "#6A737D",
        html: "#22863A",
        frontMatter: "#6F42C1"
    )

    public static let dark = Self(
        background: "#1E1E1E",
        foreground: "#F5F5F5",
        heading: "#569CD6",
        emphasis: "#569CD6",
        strong: "#569CD6",
        strikethrough: "#CE9178",
        code: "#9CDCFE",
        linkText: "#4FC1FF",
        linkDestination: "#CE9178",
        listMarker: "#808080",
        quoteMarker: "#808080",
        thematicBreak: "#808080",
        html: "#4EC9B0",
        frontMatter: "#C586C0"
    )

    public func color(for kind: MarkdownSyntaxTokenKind) -> String {
        switch kind {
        case .heading: heading
        case .emphasis: emphasis
        case .strong: strong
        case .strikethrough: strikethrough
        case .code: code
        case .linkText: linkText
        case .linkDestination: linkDestination
        case .listMarker: listMarker
        case .quoteMarker: quoteMarker
        case .thematicBreak: thematicBreak
        case .html: html
        case .frontMatter: frontMatter
        }
    }

    private init(
        background: String,
        foreground: String,
        heading: String,
        emphasis: String,
        strong: String,
        strikethrough: String,
        code: String,
        linkText: String,
        linkDestination: String,
        listMarker: String,
        quoteMarker: String,
        thematicBreak: String,
        html: String,
        frontMatter: String
    ) {
        self.background = background
        self.foreground = foreground
        self.heading = heading
        self.emphasis = emphasis
        self.strong = strong
        self.strikethrough = strikethrough
        self.code = code
        self.linkText = linkText
        self.linkDestination = linkDestination
        self.listMarker = listMarker
        self.quoteMarker = quoteMarker
        self.thematicBreak = thematicBreak
        self.html = html
        self.frontMatter = frontMatter
    }
}
