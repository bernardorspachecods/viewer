import Foundation
import Markdown

struct MarkdownHTMLDocument {
    let body: String

    var rendered: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: file: http: https:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
          <style>
        \(MarkdownStylesheet.css(tokens: MarkdownStyleTokens.shared))
          </style>
        </head>
        <body>
        <main class="bp-document-content">
        \(body)
        </main>
        </body>
        </html>
        """
    }
}
