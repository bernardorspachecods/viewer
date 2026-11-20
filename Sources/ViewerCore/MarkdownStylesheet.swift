import Foundation

/// The preview's CSS. Every size, spacing and color that `MarkdownStyleTokens` defines is read
/// from those tokens here, so the preview and the editor share one definition. Rules that have no
/// token (editing outlines, the special placeholder chrome, math) stay literal.
enum MarkdownStylesheet {
    static func css(tokens: MarkdownStyleTokens) -> String {
        [
            root(),
            page(tokens),
            content(tokens),
            blocks(tokens),
            headings(tokens),
            inline(tokens),
            code(tokens),
            quotes(tokens),
            tables(tokens),
            lists(tokens),
            chrome(tokens),
            editing(tokens),
            math(tokens)
        ].joined(separator: "\n")
    }

    /// A CSS number: whole values without a decimal point, so `15` reads `15px`, not `15.0px`.
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func px(_ value: Double) -> String {
        number(value) + "px"
    }

    private static func em(_ value: Double) -> String {
        number(value) + "em"
    }

    private static func root() -> String {
        """
        :root { color-scheme: light dark; }
        """
    }

    private static func page(_ tokens: MarkdownStyleTokens) -> String {
        """
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
          padding: \(px(tokens.verticalInset)) \(px(tokens.horizontalInset)) 80px;
          color: \(tokens.textColor.css);
          background: -apple-system-background;
          font-family: -apple-system, system-ui, sans-serif;
          font-size: \(px(tokens.bodyFontSize));
          line-height: \(number(tokens.lineHeight));
        }
        """
    }

    private static func content(_ tokens: MarkdownStyleTokens) -> String {
        """
        .bp-document-content {
          box-sizing: border-box;
          width: 100%;
          min-width: 0;
          max-width: var(--bp-content-max, \(px(tokens.readingWidth)));
          margin: 0 auto;
        }
        .bp-document-content > * {
          content-visibility: auto;
          contain-intrinsic-size: auto 72px;
        }
        .bp-document-content > :first-child { margin-top: 0; padding-top: 0; }
        """
    }

    /// Blocks that share the reading rhythm: one spacing between any two of them.
    private static func blocks(_ tokens: MarkdownStyleTokens) -> String {
        """
        p, ul, ol, pre, blockquote, table, .math-block, hr, .bp-front-matter {
          margin: 0 0 \(em(tokens.blockSpacingEm));
        }
        hr {
          margin-bottom: \(px(tokens.blockSpacingEm * tokens.bodyFontSize + tokens.ruleSpaceAfter));
          height: 0;
          border: 0;
          border-top: \(px(tokens.tableBorderWidth)) solid \(tokens.tableBorderColor.css);
        }
        """
    }

    private static func headings(_ tokens: MarkdownStyleTokens) -> String {
        // The editor puts a blank line before a heading and adds the heading's own top spacing on
        // top of it. Margins would collapse into one, so the extra spacing is padding.
        let rules = (1...6).map { level in
            let scale = tokens.headingScale(level: level)
            let extra = max(0, tokens.headingTopSpacingEm(level: level) * scale * tokens.bodyFontSize
                - tokens.headingBaselineShift)
            return "h\(level) { font-size: \(em(scale)); padding-top: \(px(extra)); }"
        }
        return ([
            "h1, h2, h3, h4, h5, h6 {",
            "  margin: \(px(tokens.blockSpacingEm * tokens.bodyFontSize)) 0 "
                + "\(px(tokens.blockSpacingEm * tokens.bodyFontSize + tokens.headingBaselineShift));",
            "  font-weight: 700;",
            "  line-height: 1.25;",
            "  scroll-margin-top: 24px;",
            "}"
        ] + rules).joined(separator: "\n")
    }

    private static func inline(_ tokens: MarkdownStyleTokens) -> String {
        """
        a {
          color: \(tokens.linkColor.css);
          text-decoration: underline;
          text-underline-offset: 2px;
        }
        del, s { text-decoration: line-through; }
        """
    }

    private static func code(_ tokens: MarkdownStyleTokens) -> String {
        let font = "font-family: ui-monospace, SFMono-Regular, Menlo, monospace;"
        let size = "font-size: \(em(tokens.codeFontScale));"
        return """
        pre, code { \(font) }
        code, pre { \(size) }
        code {
          padding: 0.1em 0;
          border-radius: 4px;
          background: \(tokens.codeBackground.css);
        }
        pre {
          margin-bottom: \(px(tokens.blockSpacingEm * tokens.bodyFontSize + tokens.codeSpaceAfter));
          overflow-x: auto;
          padding: \(px(tokens.codeFenceLineHeight)) \(px(tokens.codeBlockHorizontalPadding));
          border-radius: \(px(tokens.codeBlockCornerRadius));
          background: \(tokens.codeBackground.css);
        }
        pre code { font-size: 1em; padding: 0; background: transparent; }
        """
    }

    private static func quotes(_ tokens: MarkdownStyleTokens) -> String {
        """
        blockquote {
          margin-left: \(px(tokens.quoteBarInset));
          padding-left: \(px(tokens.quoteIndent - tokens.quoteBarInset - tokens.quoteBarWidth));
          border-left: \(px(tokens.quoteBarWidth)) solid \(tokens.quoteBarColor.css);
          color: \(tokens.quoteTextColor.css);
        }
        blockquote > :last-child { margin-bottom: 0; }
        """
    }

    private static func tables(_ tokens: MarkdownStyleTokens) -> String {
        let border = "\(px(tokens.tableBorderWidth)) solid \(tokens.tableBorderColor.css)"
        let padding = "\(px(tokens.tableCellVerticalPadding)) \(px(tokens.tableCellHorizontalPadding))"
        // Full width with equal columns (table-layout: fixed) or sized to content.
        let width = tokens.tableFillsWidth
            ? "width: 100%;\n  table-layout: fixed;"
            : "width: max-content;\n  max-width: 100%;"
        // Alpha 0 is "no header fill", the same as the editor's `.clear`.
        let headerBackground = tokens.tableHeaderBackground.alpha == 0
            ? ""
            : "\n  background: \(tokens.tableHeaderBackground.css);"
        return """
        table {
          display: table;
          \(width)
          border-collapse: collapse;
          margin: \(px(tokens.blockSpacingEm * tokens.bodyFontSize + tokens.tableSpaceBefore)) 0 \(px(tokens.blockSpacingEm * tokens.bodyFontSize + tokens.tableSpaceAfter));
          font: inherit;
        }
        th, td {
          vertical-align: top;
          border: \(border);
          overflow-wrap: anywhere;
          padding: \(padding);
          line-height: \(number(tokens.tableLineHeight));
          text-align: left;
        }
        th {
          font-weight: 700;\(headerBackground)
        }
        """
    }

    private static func lists(_ tokens: MarkdownStyleTokens) -> String {
        """
        ul { padding-left: \(px(tokens.listIndentPerLevel + tokens.listBulletMarkerWidth)); }
        ol { padding-left: \(px(tokens.listIndentPerLevel + tokens.listNumberMarkerWidth)); }
        li > ul, li > ol { padding-left: \(px(tokens.listNestedIndent)); }
        li > p, li > ul, li > ol { margin: 0; }
        ul > li { position: relative; list-style: none; }
        ul > li::before {
          content: "\\2022";
          position: absolute;
          left: \(px(-tokens.listBulletMarkerWidth + tokens.listBulletInset));
        }
        ul > li:has(> input[data-bp-task-checkbox="true"])::before { content: ""; }
        ul > li:has(> input[data-bp-task-checkbox]) { list-style: none; }
        input[data-bp-task-checkbox] + p { display: inline; }
        ol > li { position: relative; list-style: none; }
        ol > li::before {
          content: counter(list-item) ".";
          position: absolute;
          left: \(px(-tokens.listNumberMarkerWidth));
        }
        input[data-bp-task-checkbox] {
          appearance: none;
          position: absolute;
          left: \(px(-(tokens.taskBoxSize + tokens.taskBoxGap)));
          top: calc(\(em((tokens.lineHeight - tokens.taskBoxSize / tokens.bodyFontSize) / 2)) + \(px(tokens.taskBoxTopNudge)));
          box-sizing: border-box;
          width: \(px(tokens.taskBoxSize));
          height: \(px(tokens.taskBoxSize));
          margin: 0;
          border: 1.5px solid \(tokens.mutedColor.css);
          border-radius: 3px;
        }
        input[data-bp-task-checkbox]:checked { background: \(tokens.taskBoxCheckedFill.css); }
        input[data-bp-task-checkbox]:checked::after {
          content: "\\2713";
          position: absolute;
          inset: 0;
          color: \(tokens.textColor.css);
          font-size: 10px;
          line-height: 10px;
          text-align: center;
        }
        li:has(> input[data-bp-task-checkbox]:checked) { text-decoration: line-through; }
        """
    }

    private static func chrome(_ tokens: MarkdownStyleTokens) -> String {
        """
        img { max-width: 100%; height: auto; border-radius: 8px; }
        .bp-special-placeholder {
          cursor: pointer;
          margin: 0.8em 0;
          padding: 8px 12px;
          border-radius: 6px;
          background: color-mix(in srgb, currentColor 5%, transparent);
          color: \(tokens.mutedColor.css);
          font-size: 0.82em;
          line-height: 1.5;
          white-space: pre-wrap;
          overflow-wrap: anywhere;
        }
        span.bp-special-placeholder { display: inline; margin: 0; padding: 0.1em 0; white-space: pre-wrap; font-size: \(em(tokens.commentFontScale)); color: \(tokens.commentColor.css); background: \(tokens.commentBackground.css); }
        span.bp-special-placeholder { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
        .bp-html-block::before, .bp-front-matter-text::before {
          display: block;
          margin-bottom: 4px;
          font: -apple-system-caption2;
          font-weight: 600;
          letter-spacing: 0.06em;
          text-transform: uppercase;
          opacity: 0.8;
        }
        .bp-html-block::before { content: "HTML"; }
        .bp-front-matter-text::before { content: "Front matter"; }
        .bp-front-matter {
          padding: \(px(tokens.frontMatterVerticalPadding)) \(px(tokens.frontMatterHorizontalPadding));
          border-radius: \(px(tokens.frontMatterCornerRadius));
          background: \(tokens.frontMatterBackground.css);
          color: \(tokens.frontMatterTextColor.css);
          font-size: \(em(tokens.frontMatterFontScale));
          line-height: \(number(tokens.frontMatterLineHeight));
        }
        .bp-document-content > .bp-front-matter:first-child { padding-top: \(px(tokens.frontMatterVerticalPadding)); }
        .bp-front-matter dl { display: grid; grid-template-columns: max-content minmax(0, 1fr); gap: \(px(tokens.frontMatterRowGap)) 16px; margin: 0; }
        .bp-front-matter dt { font-weight: 600; color: \(tokens.frontMatterKeyColor.css); }
        .bp-front-matter dd { margin: 0; overflow-wrap: anywhere; }
        """
    }

    private static func editing(_ tokens: MarkdownStyleTokens) -> String {
        let link = tokens.linkColor.css
        return """
        [data-bp-block-id] { transition: background-color 120ms ease, outline-color 120ms ease; }
        [data-bp-block-id].bp-editing {
          outline: 2px solid color-mix(in srgb, \(link) 38%, transparent);
          outline-offset: 5px;
          border-radius: 5px;
          background: color-mix(in srgb, \(link) 6%, transparent);
        }
        body.bp-document-editing { caret-color: \(link); }
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
          line-height: \(number(tokens.lineHeight));
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
        """
    }

    private static func math(_ tokens: MarkdownStyleTokens) -> String {
        """
        .math-inline {
          display: inline-block;
          max-width: 100%;
          vertical-align: -0.08em;
          padding: 0.04em 0;
        }
        .math-block {
          margin-top: \(px(tokens.mathSpaceBefore));
          box-sizing: border-box;
          display: block;
          max-width: 100%;
          overflow-x: auto;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: \(px(3 * tokens.lineHeight * tokens.bodyFontSize));
          text-align: center;
        }
        .math-block math { max-width: 100%; }
        """
    }
}
