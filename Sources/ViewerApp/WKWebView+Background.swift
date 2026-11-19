import WebKit

extension WKWebView {
    /// Makes the web view transparent so the surrounding preview background shows through.
    func disableDrawsBackground() {
        setValue(false, forKey: "drawsBackground")
    }
}
