import AppKit
import ViewerCore

extension MarkdownNSTextView {
    func drawLineNumbers(in rect: NSRect, fragments: [LineFragment]) {
        guard lineNumberGutterWidth > 0 else { return }

        var drawnPhysicalLines = Set<Int>()

        for fragment in fragments {
            guard fragment.rect.intersects(rect),
                  drawnPhysicalLines.insert(fragment.physicalLine).inserted else {
                continue
            }
            drawLineNumber(
                lineNumber: lineNumber(forPhysicalLine: fragment.physicalLine),
                kind: lineHighlights[fragment.physicalLine],
                baselineY: fragment.baselineY
            )
        }
    }

    private func drawLineNumber(
        lineNumber: Int?,
        kind: DocumentDiffCellKind?,
        baselineY: CGFloat
    ) {
        let font = NSFont.monospacedSystemFont(ofSize: lineNumberFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let point: NSPoint
        if let lineNumber {
            let label = String(lineNumber) as NSString
            let width = label.size(withAttributes: attributes).width
            point = NSPoint(
                x: lineNumberGutterWidth - width - SourceEditorLayout.lineNumberTrailingPadding,
                y: baselineY
            )
            label.draw(with: NSRect(origin: point, size: .zero), options: [], attributes: attributes)
        } else {
            point = NSPoint(
                x: SourceEditorLayout.lineMarkerLeadingPadding,
                y: baselineY
            )
        }

        let marker: String
        let markerColor: NSColor
        switch kind {
        case .added:
            marker = "+"
            markerColor = .systemGreen
        case .removed:
            marker = "−"
            markerColor = .systemRed
        case .unchanged, .none:
            return
        }
        (marker as NSString).draw(
            with: NSRect(
                x: SourceEditorLayout.lineMarkerLeadingPadding,
                y: point.y,
                width: 0,
                height: 0
            ),
            options: [],
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: lineNumberFontSize, weight: .semibold),
                .foregroundColor: markerColor
            ]
        )
    }

    private func lineNumber(forPhysicalLine physicalLine: Int) -> Int? {
        lineNumberOverrides.isEmpty
            ? physicalLine
            : lineNumberOverrides[physicalLine]
    }

    func drawLineNumberSeparator() {
        guard showsLineNumbers, lineNumberGutterWidth > 0 else { return }
        NSColor.separatorColor.withAlphaComponent(0.2).setStroke()
        let separator = NSBezierPath()
        separator.move(to: NSPoint(
            x: lineNumberGutterWidth,
            y: visibleRect.minY
        ))
        separator.line(to: NSPoint(
            x: lineNumberGutterWidth,
            y: visibleRect.maxY
        ))
        separator.lineWidth = 0.5
        separator.stroke()
    }

    func drawLineHighlights(in rect: NSRect, fragments: [LineFragment]) {
        guard !lineHighlights.isEmpty else { return }

        for fragment in fragments where fragment.rect.intersects(rect) {
            drawLineHighlight(
                for: lineHighlights[fragment.physicalLine],
                lineRect: fragment.rect
            )
        }
    }

    private func drawLineHighlight(
        for kind: DocumentDiffCellKind?,
        lineRect: NSRect
    ) {
        guard let kind,
              let color = lineHighlightColor(for: kind) else { return }

        let backgroundRect = SourceEditorLayout.lineHighlightRect(
            lineFragmentRect: lineRect,
            textContainerOrigin: .zero,
            viewWidth: bounds.width
        )
        color.setFill()
        backgroundRect.fill()
    }

    private func lineHighlightColor(for kind: DocumentDiffCellKind) -> NSColor? {
        switch kind {
        case .added:
            NSColor.systemGreen.withAlphaComponent(0.2)
        case .removed:
            NSColor.systemRed.withAlphaComponent(0.2)
        case .unchanged:
            nil
        }
    }
}
