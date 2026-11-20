import SwiftUI
import ViewerCore

struct DocumentWorkspaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.chromeLayout.showsTabBar {
                TabBarView()
                Divider()
            }
            DocumentSurfaceView()
        }
        .background(BPTokens.Color.canvas)
    }
}

struct DocumentSurfaceView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveredSide: DocumentSplitSide?

    var body: some View {
        GeometryReader { proxy in
            let surfaceWidth = Double(proxy.size.width)
            surfaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    splitHighlight(surfaceWidth: proxy.size.width, height: proxy.size.height)
                }
                // A drop changes which tabs are shown; the highlight must not outlive it.
                .onChange(of: model.visibleTabIDs) { _, _ in hoveredSide = nil }
                .onChange(of: model.activeSide) { _, _ in hoveredSide = nil }
                .background(
                    DropHighlightReset(isActive: hoveredSide != nil) { hoveredSide = nil }
                )
                .onDrop(
                    of: [.viewerTab],
                    delegate: DocumentSplitDropDelegate(
                        model: model,
                        surfaceWidth: surfaceWidth,
                        hoveredSide: $hoveredSide
                    )
                )
        }
    }

    @ViewBuilder
    private var surfaceContent: some View {
        if model.isSplit, let leading = model.leadingTab, let trailing = model.trailingTab {
            ResizableSplitView(minimumLeadingWidth: 320, minimumTrailingWidth: 320) {
                splitPane(leading)
            } trailing: {
                splitPane(trailing)
            }
        } else if let tab = model.activeTab {
            PreviewPane(tab: tab)
        } else {
            EmptyStateView(
                systemImage: "doc.text.magnifyingglass",
                title: "No Document Selected",
                message: model.rootURL == nil
                    ? "Open a folder and choose a Markdown, LaTeX, JSON, DOCX, or PDF file."
                    : "Choose a file in the tree to open a tab."
            )
        }
    }

    private func splitPane(_ tab: DocumentTab) -> some View {
        PreviewPane(tab: tab, isFocusedPane: model.activeTabID == tab.id)
            .id(tab.id)
            .background(
                PaneFocusTracker {
                    if model.activeTabID != tab.id {
                        model.selectTab(id: tab.id)
                    }
                }
            )
    }

    @ViewBuilder
    private func splitHighlight(surfaceWidth: CGFloat, height: CGFloat) -> some View {
        if let hoveredSide {
            let halfWidth = surfaceWidth / 2
            Rectangle()
                .fill(Color.accentColor.opacity(0.18))
                .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 2))
                .frame(width: halfWidth, height: height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hoveredSide == .leading ? .leading : .trailing)
                .allowsHitTesting(false)
        }
    }
}
