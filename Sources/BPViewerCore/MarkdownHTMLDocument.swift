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
            :root { color-scheme: light dark; }
            html {
              width: 100%;
              min-width: 0;
              overflow-x: hidden;
              overflow-y: scroll;
              scrollbar-gutter: stable;
            }
            body {
              box-sizing: border-box;
              width: 100%;
              min-width: 0;
              max-width: none;
              margin: 0;
              padding: 40px 52px 80px;
              color: -apple-system-label;
              background: -apple-system-background;
              font: -apple-system-body;
              line-height: 1.55;
            }
            .bp-document-content {
              box-sizing: border-box;
              width: 100%;
              min-width: 0;
              max-width: 860px;
              margin: 0 auto;
            }
            .bp-document-content > * {
              content-visibility: auto;
              contain-intrinsic-size: auto 72px;
            }
            [data-bp-block-id] { transition: background-color 120ms ease, outline-color 120ms ease; }
            [data-bp-block-id].bp-editing {
              outline: 2px solid color-mix(in srgb, -apple-system-blue 38%, transparent);
              outline-offset: 5px;
              border-radius: 5px;
              background: color-mix(in srgb, -apple-system-blue 6%, transparent);
            }
            body.bp-document-editing { caret-color: -apple-system-blue; }
            body.bp-document-editing [data-bp-editable="true"] { cursor: text; }
            body.bp-raw-mode > *:not(#bp-raw-editor) { display: none !important; }
            #bp-raw-editor {
              display: block;
              box-sizing: border-box;
              width: 100%;
              min-height: calc(100vh - 80px);
              resize: none;
              border: 0;
              outline: 0;
              padding: 0;
              color: inherit;
              background: transparent;
              font: ui-monospace, SFMono-Regular, Menlo, monospace;
              line-height: 1.55;
              white-space: pre-wrap;
            }
            .bp-special-editor {
              position: fixed;
              z-index: 20;
              top: 16px;
              right: 16px;
              display: grid;
              gap: 8px;
              min-width: 280px;
              padding: 12px;
              border: 1px solid color-mix(in srgb, currentColor 20%, transparent);
              border-radius: 8px;
              background: -apple-system-control-background;
              box-shadow: 0 8px 28px color-mix(in srgb, black 25%, transparent);
              font: -apple-system-caption1;
            }
            .bp-special-editor label { display: grid; gap: 3px; }
            .bp-special-editor input { box-sizing: border-box; width: 100%; }
            .bp-special-editor span { display: flex; justify-content: flex-end; gap: 6px; }
            h1, h2, h3, h4, h5, h6 { line-height: 1.2; margin-top: 1.5em; scroll-margin-top: 24px; }
            h1 { font-size: 1.55em; }
            h2 { font-size: 1.3em; }
            h3 { font-size: 1.1em; }
            h4 { font-size: 0.95em; }
            h5 { font-size: 0.8em; }
            h6 { font-size: 0.65em; }
            h1:first-child { margin-top: 0; }
            a { color: -apple-system-blue; }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
            code { padding: 0.12em 0.3em; border-radius: 4px; background: color-mix(in srgb, currentColor 10%, transparent); }
            pre { overflow-x: auto; padding: 16px; border-radius: 8px; background: color-mix(in srgb, currentColor 8%, transparent); }
            pre code { padding: 0; background: transparent; }
            blockquote { margin-left: 0; padding-left: 16px; border-left: 3px solid color-mix(in srgb, currentColor 25%, transparent); }
            table {
              border-collapse: separate;
              border-spacing: 0;
              width: 100%;
              max-width: 100%;
              table-layout: fixed;
              font: inherit;
            }
            th, td {
              border: 0;
              border-right: 1px solid color-mix(in srgb, currentColor 20%, transparent);
              border-bottom: 1px solid color-mix(in srgb, currentColor 20%, transparent);
              overflow-wrap: anywhere;
              padding: 8px 10px;
              text-align: left;
            }
            table tr:first-child > th,
            table tr:first-child > td {
              border-top: 1px solid color-mix(in srgb, currentColor 20%, transparent);
            }
            table th:first-child,
            table td:first-child {
              border-left: 1px solid color-mix(in srgb, currentColor 20%, transparent);
            }
            .bp-special-placeholder { cursor: pointer; border: 1px dashed color-mix(in srgb, currentColor 28%, transparent); border-radius: 6px; padding: 10px; color: -apple-system-secondary-label; white-space: pre-wrap; }
            .math-inline {
              display: inline-block;
              max-width: 100%;
              vertical-align: -0.08em;
              padding: 0.04em 0.18em;
              border-radius: 4px;
              background: color-mix(in srgb, -apple-system-blue 7%, transparent);
            }
            .math-block {
              box-sizing: border-box;
              display: block;
              max-width: 100%;
              overflow-x: auto;
              margin: 1em 0;
              padding: 0.5em 0.75em;
              border-radius: 6px;
              background: color-mix(in srgb, currentColor 5%, transparent);
              text-align: center;
            }
            .math-block math { max-width: 100%; }
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
