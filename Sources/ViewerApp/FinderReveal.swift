import AppKit
import Foundation

/// Seam for showing an item in Finder, so the menu wiring and tests do not open Finder.
protocol FinderRevealing {
    func reveal(_ url: URL)
}

struct SystemFinderRevealer: FinderRevealing {
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
