import ViewerCore
import SwiftUI

struct PreviewPane: View {
    @EnvironmentObject var model: AppModel
    let tab: DocumentTab
    /// False for the non-focused pane of a split: its find is inert and it draws no focus mark.
    var isFocusedPane: Bool = true

    /// The find query this pane receives. Find applies to the focused pane only.
    var paneFindQuery: String { isFocusedPane ? model.findQuery : "" }

    /// Match counts from the non-focused pane must not overwrite the focused pane's count.
    var paneFindMatchCount: @MainActor @Sendable (Int) -> Void {
        let model = model
        let isFocused = isFocusedPane
        return { count in
            if isFocused { model.setFindMatchCount(count) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isFindBarVisible && isFocusedPane {
                PreviewFindBar()
            }

            VStack(spacing: 0) {
                previewContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BPTokens.Color.canvas)
        .overlay(alignment: .top) {
            previewErrorOverlay(showingStalePreview: tab.isStale)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if tab.kind == .markdown, let html = tab.previewHTML {
            markdownPreview(html: html)
        } else if tab.kind == .json, let source = tab.jsonSource ?? tab.previewJSON {
            jsonPreview(source: source)
        } else if tab.kind == .csv, let document = tab.previewCSV {
            csvPreview(document: document)
        } else if tab.kind == .latex, let pdfData = tab.previewPDFData {
            latexPreview(pdfData: pdfData)
        } else if tab.kind == .pdf, let pdfData = tab.previewPDFData {
            pdfPreview(pdfData: pdfData)
        } else if tab.kind == .image, let imageData = tab.previewImageData {
            imagePreview(imageData: imageData)
        } else if tab.kind == .docx {
            docxPreview
        } else {
            emptyPreview
        }
    }

    private var emptyPreview: some View {
        VStack(spacing: 0) {
            EmptyStateView(
                systemImage: emptyStateSystemImage,
                title: emptyStateTitle,
                message: emptyStateMessage
            )
        }
    }

    @ViewBuilder
    private func previewErrorOverlay(showingStalePreview: Bool) -> some View {
        if let errorMessage = tab.errorMessage {
            if tab.kind == .json && tab.jsonEditSession?.isEditing == true {
                PreviewErrorBanner(
                    message: errorMessage,
                    showingStalePreview: showingStalePreview,
                    title: "Invalid JSON — Not Saved"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BPTokens.Spacing.md)
                .padding(.vertical, BPTokens.Spacing.xs)
            } else {
                PreviewErrorBanner(
                    message: errorMessage,
                    showingStalePreview: showingStalePreview,
                    onRetry: model.refreshActiveTab
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BPTokens.Spacing.md)
                .padding(.vertical, BPTokens.Spacing.xs)
            }
        }
    }

    private var emptyStateSystemImage: String {
        return switch tab.kind {
        case .latex: "doc.text.image"
        case .json: "curlybraces"
        case .csv: "tablecells"
        case .pdf: "doc.fill"
        case .docx: "doc.text.fill"
        case .image: "photo"
        case .markdown: "doc.richtext"
        case .other: "doc"
        }
    }

    private var emptyStateTitle: String {
        guard tab.errorMessage == nil else { return "Unable to Generate Preview" }
        return switch tab.kind {
        case .latex: "Preparing LaTeX Preview…"
        case .json: "Preparing JSON Preview…"
        case .csv: "Preparing CSV Preview…"
        case .pdf: "Preparing PDF Preview…"
        case .docx: "Preparing Word Preview…"
        case .image: "Preparing Image Preview…"
        case .markdown, .other: "Preparing Preview…"
        }
    }

    private var emptyStateMessage: String {
        guard tab.errorMessage == nil else {
            return "Review the details above, fix the problem, and try again."
        }
        return switch tab.kind {
        case .latex: "Compiling the main document with the local LaTeX installation."
        case .json: "Validating and formatting the JSON file."
        case .csv: "Reading and formatting the CSV file as a table."
        case .pdf: "Reading the PDF file."
        case .docx: "Preparing the Word document view."
        case .image: "Reading the image file."
        case .markdown: "Reading the Markdown file and generating HTML."
        case .other: "Preparing the file."
        }
    }
}
