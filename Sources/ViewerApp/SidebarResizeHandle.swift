import AppKit
import SwiftUI

struct ResizableSidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var liveWidth: Double?

    private var displayedWidth: Double {
        liveWidth ?? model.sidebarWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: displayedWidth)
            SidebarResizeHandle(
                width: displayedWidth,
                onChanged: { liveWidth = $0 },
                onEnded: { width in
                    model.setSidebarWidth(width)
                    liveWidth = nil
                }
            )
        }
    }
}

struct SidebarResizeHandle: View {
    let width: Double
    let onChanged: (Double) -> Void
    let onEnded: (Double) -> Void
    let minimumWidth: Double
    let maximumWidth: Double
    let helpText: String

    @State private var initialWidth: Double?
    @State private var isHovering = false

    init(
        width: Double,
        minimumWidth: Double = Double(BPTokens.Size.sidebarMin),
        maximumWidth: Double = Double(BPTokens.Size.sidebarMax),
        helpText: String = "Resize Sidebar",
        onChanged: @escaping (Double) -> Void,
        onEnded: @escaping (Double) -> Void
    ) {
        self.width = width
        self.minimumWidth = minimumWidth
        self.maximumWidth = maximumWidth
        self.helpText = helpText
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 5)
            .overlay {
                Rectangle()
                    .fill(isHovering ? Color.accentColor.opacity(0.45) : BPTokens.Color.separator)
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if initialWidth == nil {
                            initialWidth = width
                        }
                        guard let baseWidth = initialWidth else { return }
                        let resizedWidth = min(
                            max(baseWidth + value.translation.width, minimumWidth),
                            maximumWidth
                        )
                        onChanged(resizedWidth)
                    }
                    .onEnded { value in
                        guard let baseWidth = initialWidth else { return }
                        let resizedWidth = min(
                            max(baseWidth + value.translation.width, minimumWidth),
                            maximumWidth
                        )
                        onEnded(resizedWidth)
                        initialWidth = nil
                    }
            )
            .help(helpText)
    }
}
