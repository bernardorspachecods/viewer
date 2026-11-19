import Foundation

/// URL bridge used by the Markdown preview for explicit local-file navigation.
///
/// A local file URL is not used directly in the generated HTML because a
/// document loaded with `WKWebView.loadHTMLString` may expose the link in the
/// context menu without producing a navigation action for the relative file
/// destination. The app-owned URL makes that navigation explicit while the
/// actual file path remains in a query item.
public enum MarkdownPreviewLink {
    public static let scheme = "viewer"
    public static let host = "open-local-file"

    /// The bridge URL for a local file, carrying the fragment (decoded) so the
    /// opened document can scroll to that heading.
    public static func url(for fileURL: URL, fragment: String? = nil) -> URL? {
        guard fileURL.isFileURL else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "path", value: fileURL.standardizedFileURL.path)
        ]
        components.fragment = fragment?.isEmpty == false ? fragment : nil
        return components.url
    }

    public static func fileURL(from url: URL) -> URL? {
        guard let components = bridgeComponents(of: url),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    /// The decoded fragment carried by a bridge URL, if any.
    public static func fragment(from url: URL) -> String? {
        bridgeComponents(of: url)?.fragment
    }

    private static func bridgeComponents(of url: URL) -> URLComponents? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host else {
            return nil
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)
    }
}
