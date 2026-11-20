import ViewerCore
import SwiftUI

/// The single window header. Workspace identity (sidebar toggle, folder, name,
/// path) sits on the left in normal windows; the active document's title and
/// path follow it. The right side shows the document's update time and status,
/// its document controls, and the theme toggle. Reader windows omit the
/// workspace controls but keep the document identity, status, and controls.
struct WorkspaceHeaderBar: View {
    @EnvironmentObject private var model: AppModel
    @State private var isWorkspaceTitleHovered = false
    @State private var isWorkspacePathHovered = false
    @State private var isDocumentTitleHovered = false
    @State private var isDocumentPathHovered = false

    private var workspaceTitle: String {
        model.rootURL?.lastPathComponent ?? "Viewer"
    }

    private var workspacePath: String {
        model.rootURL?.path ?? "No Folder Open"
    }

    var body: some View {
        HStack(spacing: BPTokens.Spacing.sm) {
            leadingItems
            Spacer(minLength: BPTokens.Spacing.md)
            HStack(spacing: BPTokens.Spacing.sm) {
                trailingItems
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, BPTokens.Spacing.md)
        .frame(height: BPTokens.Size.toolbar)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(BPTokens.Color.surface)
    }

    @ViewBuilder
    private var leadingItems: some View {
        if !model.presentation.isReader {
            if BuildChannel.current.isDevelopment {
                DevChannelBadge()
            }

            ToolbarIconButton(
                systemName: "sidebar.left",
                help: model.sidebarVisible ? "Hide Sidebar" : "Show Sidebar"
            ) {
                model.setSidebarVisible(!model.sidebarVisible)
            }

            ToolbarIconButton(systemName: "folder", help: "Open Folder") {
                model.openFolder()
            }

            workspaceIdentity
        }

        if let tab = model.activeTab {
            if !model.presentation.isReader {
                Rectangle()
                    .fill(BPTokens.Color.separator)
                    .frame(width: 1, height: BPTokens.Spacing.md)
            }
            documentIdentity(tab)
                .layoutPriority(1)
        }
    }

    private var workspaceIdentity: some View {
        HStack(alignment: .firstTextBaseline, spacing: BPTokens.Spacing.xs) {
            HStack(spacing: BPTokens.Spacing.xxs) {
                Text(workspaceTitle)
                    .font(BPTokens.Typography.title)
                    .fixedSize(horizontal: true, vertical: false)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy Title") { model.copyText(workspaceTitle) }
                    }
                CopyTextButton(text: workspaceTitle, isVisible: isWorkspaceTitleHovered) {
                    model.copyText($0)
                }
            }
            .onHover { isWorkspaceTitleHovered = $0 }

            HStack(spacing: BPTokens.Spacing.xxs) {
                Text(workspacePath)
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(BPTokens.Color.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .contextMenu {
                        if model.rootURL != nil {
                            Button("Copy Path") { model.copyText(workspacePath) }
                        }
                    }
                CopyTextButton(
                    text: workspacePath,
                    isVisible: isWorkspacePathHovered && model.rootURL != nil,
                    helpText: "Copy Path"
                ) {
                    model.copyText($0)
                }
            }
            .onHover { isWorkspacePathHovered = $0 }
        }
    }

    private func documentIdentity(_ tab: DocumentTab) -> some View {
        let path = tab.isUntitled
            ? "Not saved"
            : FilePathCopy.string(for: tab.kind == .latex ? tab.editableSourceURL : tab.url)

        return HStack(alignment: .firstTextBaseline, spacing: BPTokens.Spacing.xs) {
            HStack(spacing: BPTokens.Spacing.xxs) {
                Text(tab.title)
                    .font(BPTokens.Typography.body.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(2)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy Title") { model.copyText(tab.title) }
                    }
                CopyTextButton(text: tab.title, isVisible: isDocumentTitleHovered) {
                    model.copyText($0)
                }
            }
            .onHover { isDocumentTitleHovered = $0 }

            HStack(spacing: BPTokens.Spacing.xxs) {
                Text(path)
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(BPTokens.Color.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                    .textSelection(.enabled)
                    .contextMenu {
                        if !tab.isUntitled {
                            Button("Copy Path") { model.copyPath(tab.url) }
                        }
                    }
                CopyTextButton(text: path, isVisible: isDocumentPathHovered, helpText: "Copy Path") {
                    model.copyText($0)
                }
            }
            .onHover { isDocumentPathHovered = $0 }
        }
    }

    @ViewBuilder
    private var trailingItems: some View {
        if let tab = model.activeTab {
            updatedAndStatus(tab)

            if tab.kind == .latex {
                ToolbarIconButton(systemName: "list.bullet.rectangle", help: "Choose Main LaTeX Document") {
                    model.changeLatexRoot()
                }
                ToolbarMenu(systemName: "gearshape", help: "Advanced LaTeX Settings") {
                    Picker("Shell escape", selection: Binding(
                        get: { model.latexShellEscapeMode },
                        set: { model.setLatexShellEscapeMode($0) }
                    )) {
                        ForEach(LatexShellEscapeMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            }

            if model.canCaptureActivePreview {
                ToolbarIconButton(systemName: "camera.viewfinder", help: "Create Preview Snapshot") {
                    model.startSnapshotCapture()
                }
            }

            if [.markdown, .latex, .pdf, .json, .csv, .docx].contains(tab.kind) {
                ToolbarIconButton(systemName: "minus.magnifyingglass", help: "Zoom Out") {
                    model.zoomOut()
                }
                Button(action: model.resetPreviewZoom) {
                    Text("\(Int(model.previewZoom * 100))%")
                        .font(BPTokens.Typography.caption)
                        .monospacedDigit()
                        .frame(minWidth: 30)
                }
                .buttonStyle(QuietButtonStyle.text)
                .help("Reset Zoom")
                ToolbarIconButton(systemName: "plus.magnifyingglass", help: "Zoom In") {
                    model.zoomIn()
                }
            }
        }

        ToolbarIconButton(
            systemName: "arrow.up.left.and.arrow.down.right",
            help: "\(AppShortcuts.focusMode.title) (\(AppShortcuts.focusMode.display))"
        ) {
            model.toggleFocusMode()
        }

        ToolbarIconButton(systemName: model.theme == .dark ? "sun.max" : "moon", help: "Toggle Theme") {
            model.cycleTheme()
        }
    }

    private func updatedAndStatus(_ tab: DocumentTab) -> some View {
        HStack(alignment: .center, spacing: BPTokens.Spacing.xxs) {
            ToolbarIconButton(systemName: "arrow.clockwise", help: "Refresh Preview") {
                model.refreshActiveTab()
            }
            if let updatedAt = tab.previewUpdatedAt {
                Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(BPTokens.Typography.caption)
                    .foregroundStyle(BPTokens.Color.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            StatusBadge(status: tab.status, showsLabel: false)
        }
    }
}
