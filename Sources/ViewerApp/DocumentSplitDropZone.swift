import ViewerCore

/// Maps a drop position over the document surface to the pane it lands in.
enum DocumentSplitDropZone {
    static func side(forX x: Double, width: Double) -> DocumentSplitSide {
        guard width > 0 else { return .trailing }
        return x < width / 2 ? .leading : .trailing
    }
}
