import SwiftUI

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

    var body: some View {
        Group {
            if let tab = model.activeTab {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
