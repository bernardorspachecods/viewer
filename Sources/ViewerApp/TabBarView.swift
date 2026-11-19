import ViewerCore
import SwiftUI

struct TabBarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dropTargetID: String?

    private let endDropTargetID = "__tab_end__"

    var body: some View {
        HStack(spacing: 0) {
            documentTabs
            newDocumentButton
        }
        .frame(height: 38)
        .background(BPTokens.Color.surface)
        .zIndex(1)
    }

    private var documentTabs: some View {
        ScrollViewReader { scrollView in
            ScrollView(.horizontal, showsIndicators: false) {
                tabItems
            }
            .onChange(of: model.activeTabID, initial: true) { _, activeTabID in
                if let activeTabID {
                    scrollView.scrollTo(activeTabID)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tabItems: some View {
        HStack(spacing: 0) {
            ForEach(model.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isSelected: model.activeTabID == tab.id,
                    isDropTarget: dropTargetID == tab.id
                )
                .draggable(tab.id) {
                    Text(tab.title)
                        .padding(.horizontal, BPTokens.Spacing.sm)
                        .padding(.vertical, BPTokens.Spacing.xs)
                        .background(BPTokens.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: BPTokens.Radius.sm))
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let sourceID = items.first, sourceID != tab.id else { return false }
                    model.moveTab(id: sourceID, before: tab.id)
                    dropTargetID = nil
                    return true
                } isTargeted: { isTargeted in
                    if isTargeted {
                        updateDropTarget(tab.id)
                    } else if dropTargetID == tab.id {
                        updateDropTarget(nil)
                    }
                }
                .id(tab.id)
            }
        }
        .padding(.horizontal, BPTokens.Spacing.xs)
    }

    private var newDocumentButton: some View {
        ToolbarIconButton(systemName: "plus", help: "New Markdown File") {
            model.createNewMarkdownDocument()
        }
        .padding(.horizontal, BPTokens.Spacing.xs)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let sourceID = items.first else { return false }
            model.moveTabToEnd(id: sourceID)
            dropTargetID = nil
            return true
        } isTargeted: { isTargeted in
            if isTargeted || dropTargetID == endDropTargetID {
                updateDropTarget(isTargeted ? endDropTargetID : nil)
            }
        }
        .overlay(alignment: .leading) {
            let isDropTarget = dropTargetID == endDropTargetID
            Rectangle()
                .fill(isDropTarget ? Color.accentColor : BPTokens.Color.separator)
                .frame(width: isDropTarget ? 3 : 1, height: isDropTarget ? 26 : 18)
                .allowsHitTesting(false)
        }
    }

    private func updateDropTarget(_ targetID: String?) {
        withAnimation(.easeInOut(duration: 0.14)) {
            dropTargetID = targetID
        }
    }
}

struct TabItemView: View {
    @EnvironmentObject private var model: AppModel
    let tab: DocumentTab
    let isSelected: Bool
    let isDropTarget: Bool

    var body: some View {
        HStack(spacing: BPTokens.Spacing.xxs) {
            Button {
                model.selectTab(id: tab.id)
            } label: {
                HStack(spacing: BPTokens.Spacing.xs) {
                    Image(systemName: iconName)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tab.title)
                            .lineLimit(1)
                        if tab.subtitle != tab.title {
                            Text(tab.subtitle)
                                .font(.caption2)
                                .foregroundStyle(BPTokens.Color.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .font(BPTokens.Typography.caption)
                .frame(maxWidth: .infinity, minHeight: BPTokens.Size.control, alignment: .leading)
            }
            .buttonStyle(QuietButtonStyle(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                model.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: BPTokens.Size.control)
            }
            .buttonStyle(QuietButtonStyle(symbolSize: 9))
            .accessibilityLabel("Close \(tab.title)")
            .help("Close Tab")
        }
        .padding(.horizontal, BPTokens.Spacing.xs)
        .frame(width: 164, height: 38)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary)
                .frame(height: 1)
                .padding(.horizontal, BPTokens.Spacing.xxs)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .leading) {
            if isDropTarget {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.35, anchor: .leading)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .modifier(WorkspaceContextMenuModifier(target: .tab(tab)))
    }

    private var iconName: String {
        return switch tab.kind {
        case .markdown: "doc.richtext"
        case .latex: "doc.text"
        case .json: "curlybraces"
        case .csv: "tablecells"
        case .docx: "doc.text.fill"
        case .pdf: "doc.fill"
        case .image: "photo"
        case .other: "doc"
        }
    }
}
