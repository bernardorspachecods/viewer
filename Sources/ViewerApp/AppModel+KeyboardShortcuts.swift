import AppKit
import ViewerCore
import Combine
import Foundation
@preconcurrency import PDFKit
import UniformTypeIdentifiers

extension AppModel {
    /// Routes a local key-down event to the editor shortcut that owns it; returns nil when consumed.
    func handleLocalKeyDown(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard shouldHandleWindowEvents else { return event }

        if flags == [.control], event.keyCode == 48 {
            Task { @MainActor [weak self] in
                self?.selectNextTab()
            }
            return nil
        }

        if flags == [.command],
           event.charactersIgnoringModifiers?.lowercased() == "s",
           let tabID = self.activeTabID,
           let tab = self.activeTab,
           let session = tab.markdownEditSession,
           tab.isUntitled
                || session.currentSource != session.baseSource
                || session.isEditing {
            Task { @MainActor [weak self] in
                if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
                   MarkdownDraftFlushPolicy.shouldFlush(from: textView) {
                    self?.updateMarkdownEditing(
                        tabID: tabID,
                        text: textView.string,
                        rebuildBlocks: false
                    )
                }
                await self?.saveMarkdownEdit(tabID: tabID)
            }
            return nil
        }

        if flags == [.command],
           event.charactersIgnoringModifiers?.lowercased() == "s",
           let tabID = self.activeTabID,
           let session = self.activeTab?.jsonEditSession,
           session.currentSource != session.baseSource {
            Task { @MainActor [weak self] in
                await self?.saveJSONEdit(tabID: tabID)
            }
            return nil
        }

        if flags == [.command],
           event.charactersIgnoringModifiers?.lowercased() == "s",
           let tabID = self.activeTabID,
           let session = self.activeTab?.csvEditSession,
           session.currentSource != session.baseSource {
            Task { @MainActor [weak self] in
                _ = await self?.saveCSVEdit(tabID: tabID)
            }
            return nil
        }

        if flags == [.command],
           event.charactersIgnoringModifiers?.lowercased() == "s",
           let tabID = self.activeTabID,
           let session = self.activeTab?.latexEditSession,
           session.currentSource != session.baseSource {
            Task { @MainActor [weak self] in
                await self?.saveLatexEdit(tabID: tabID)
            }
            return nil
        }

        if flags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z",
           let tabID = self.activeTabID,
           let session = self.activeTab?.markdownEditSession,
           (flags.contains(.shift) ? !session.redoSources.isEmpty : !session.undoSources.isEmpty) {
            let redo = flags.contains(.shift)
            Task { @MainActor [weak self] in
                if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
                   MarkdownDraftFlushPolicy.shouldFlush(from: textView) {
                    self?.updateMarkdownEditing(
                        tabID: tabID,
                        text: textView.string,
                        rebuildBlocks: false
                    )
                }
                if redo {
                    self?.redoMarkdownEdit()
                } else {
                    self?.undoMarkdownEdit()
                }
            }
            return nil
        }

        if flags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z",
           let session = self.activeTab?.jsonEditSession,
           (flags.contains(.shift) ? !session.redoSources.isEmpty : !session.undoSources.isEmpty) {
            let redo = flags.contains(.shift)
            Task { @MainActor [weak self] in
                if redo {
                    self?.redoJSONEdit()
                } else {
                    self?.undoJSONEdit()
                }
            }
            return nil
        }

        if flags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z",
           let session = self.activeTab?.csvEditSession,
           (flags.contains(.shift) ? !session.redoSources.isEmpty : !session.undoSources.isEmpty) {
            let redo = flags.contains(.shift)
            Task { @MainActor [weak self] in
                if redo {
                    self?.redoCSVEdit()
                } else {
                    self?.undoCSVEdit()
                }
            }
            return nil
        }

        if flags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z",
           let session = self.activeTab?.latexEditSession,
           (flags.contains(.shift) ? !session.redoSources.isEmpty : !session.undoSources.isEmpty) {
            let redo = flags.contains(.shift)
            Task { @MainActor [weak self] in
                if redo {
                    self?.redoLatexEdit()
                } else {
                    self?.undoLatexEdit()
                }
            }
            return nil
        }

        return event
    }
}
