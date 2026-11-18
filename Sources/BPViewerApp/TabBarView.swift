import BPViewerCore
import SwiftUI

struct TabBarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dropTargetID: String?
    @State private var indicatorTabID: String?
    @Namespace private var activeTabIndicator

    private let endDropTargetID = "__tab_end__"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.tabs) { tab in
                    TabItemView(
                        tab: tab,
                        isIndicatorActive: indicatorTabID == tab.id,
                        isDropTarget: dropTargetID == tab.id,
                        activeTabIndicator: activeTabIndicator,
                        onSelect: { selectTab(tab.id) }
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
                }

                ToolbarIconButton(systemName: "plus", help: "New Markdown File") {
                    model.createNewMarkdownDocument()
                }
                .padding(.leading, BPTokens.Spacing.sm)

                Rectangle()
                    .fill(.clear)
                    .frame(minWidth: 36, maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                    .dropDestination(for: String.self) { items, _ in
                        guard let sourceID = items.first else { return false }
                        model.moveTabToEnd(id: sourceID)
                        dropTargetID = nil
                        return true
                    } isTargeted: { isTargeted in
                        updateDropTarget(isTargeted ? endDropTargetID : nil)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 28)
                            .opacity(dropTargetID == endDropTargetID ? 1 : 0)
                            .scaleEffect(x: dropTargetID == endDropTargetID ? 1 : 0.35, anchor: .leading)
                            .animation(.easeInOut(duration: 0.14), value: dropTargetID == endDropTargetID)
                    }
            }
            .padding(.horizontal, BPTokens.Spacing.xs)
        }
        .frame(height: 38)
        .background(BPTokens.Color.surface)
        .zIndex(1)
        .onAppear {
            indicatorTabID = model.activeTabID
        }
        .onChange(of: model.activeTabID) { _, newTabID in
            guard newTabID != indicatorTabID else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                indicatorTabID = newTabID
            }
        }
    }

    private func selectTab(_ tabID: String) {
        withAnimation(.easeOut(duration: 0.16)) {
            indicatorTabID = tabID
        }
        model.selectTab(id: tabID)
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
    let isIndicatorActive: Bool
    let isDropTarget: Bool
    let activeTabIndicator: Namespace.ID
    let onSelect: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                onSelect()
            } label: {
                HStack(spacing: BPTokens.Spacing.xs) {
                    Image(systemName: iconName)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tab.title)
                            .lineLimit(1)
                        if tab.subtitle != tab.title {
                            Text(tab.subtitle)
                                .font(BPTokens.Typography.caption)
                                .foregroundStyle(BPTokens.Color.muted)
                        }
                    }
                }
                .font(BPTokens.Typography.caption)
                .padding(.leading, BPTokens.Spacing.xs)
                .padding(.trailing, 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.closeTab(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 14, height: 14)
                    .iconButtonHitArea()
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(1)
        }
        .padding(.horizontal, BPTokens.Spacing.xs)
        .frame(minWidth: 150, minHeight: 36)
        .overlay(alignment: .bottom) {
            if isIndicatorActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .offset(y: 2)
                    .matchedGeometryEffect(
                        id: "active-tab-indicator",
                        in: activeTabIndicator,
                        properties: .position,
                        anchor: .bottom
                    )
            }
        }
        .overlay(alignment: .leading) {
            if isDropTarget {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.35, anchor: .leading)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: isIndicatorActive)
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
