import ViewerCore
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let chrome = model.chromeLayout
        VStack(spacing: 0) {
            if chrome.showsHeader {
                WorkspaceHeaderBar()
                Divider()
            }
            HStack(spacing: 0) {
                if chrome.showsSidebar {
                    ResizableSidebarView()
                }

                DocumentWorkspaceView()
            }
        }
        .background(BPTokens.Color.canvas)
        .background(WindowCloseGuard(model: model))
        .overlay(alignment: .topTrailing) {
            if chrome.showsFocusExitButton {
                FocusExitButton()
            }
        }
        // Runs only for an Esc that no focused view consumed (editors, find field and
        // sheets come first in the responder chain). A no-op when focus mode is off.
        .onExitCommand { model.exitFocusMode() }
        .preferredColorScheme(model.theme.colorScheme)
        .frame(minWidth: WorkspaceWindowMetrics.minimumWidth, minHeight: WorkspaceWindowMetrics.minimumHeight)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            for provider in providers {
                let _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        model.openDroppedURLs([url])
                    }
                }
            }
            return !providers.isEmpty
        }
        .alert("Switch Open Folder?", isPresented: $model.showingRootChangeConfirmation) {
            Button("Cancel", role: .cancel, action: model.cancelRootChange)
            Button("Switch", role: .destructive, action: model.confirmRootChange)
        } message: {
            Text("The current tabs will be closed and the new folder will become the project root.")
        }
        .alert(model.pendingFileMoveTitle, isPresented: $model.showingFileMoveConfirmation) {
            Button("Cancel", role: .cancel, action: model.cancelFileMove)
            Button("Move", role: .destructive, action: model.confirmFileMove)
        } message: {
            Text(model.pendingFileMoveMessage)
        }
        .alert(
            "Unsaved Changes",
            isPresented: $model.showingPendingCloseConfirmation
        ) {
            Button("Continue Editing", role: .cancel, action: model.cancelPendingClose)
            if model.pendingCloseCanSave {
                Button(
                    model.pendingCloseRequest?.unsavedCount ?? 1 > 1 ? "Save All" : "Save",
                    action: model.savePendingClose
                )
            }
            Button(
                model.pendingCloseRequest?.unsavedCount ?? 1 > 1 ? "Discard All" : "Discard Changes",
                role: .destructive,
                action: model.discardPendingClose
            )
        } message: {
            if model.pendingCloseRequest?.unsavedCount ?? 1 > 1 {
                Text("\(model.pendingCloseRequest?.unsavedCount ?? 0) documents have unsaved changes. Would you like to save or close without saving?")
            } else if model.pendingCloseCanSave {
                Text("\(model.pendingCloseRequest?.title ?? "This file") has unsaved changes. Would you like to edit, save, or close without saving?")
            } else {
                Text("\(model.pendingCloseRequest?.title ?? "This file") contains invalid JSON. Fix the content before saving, or close without saving.")
            }
        }
        .alert(
            "Invalid JSON",
            isPresented: $model.showingInvalidJSONConfirmation
        ) {
            Button("Continue Editing", role: .cancel, action: model.cancelInvalidJSONEditing)
            Button("Discard Changes", role: .destructive, action: model.discardInvalidJSONEditing)
        } message: {
            Text("This JSON is invalid and cannot be saved. Continue editing or discard the changes?")
        }
        .alert(
            "Discard Git Changes?",
            isPresented: $model.showingGitDiscardConfirmation
        ) {
            Button("Cancel", role: .cancel, action: model.cancelDiscardGitChanges)
            Button("Discard Git Changes", role: .destructive, action: model.confirmDiscardGitChanges)
        } message: {
            Text("\(model.pendingGitDiscardTitle) and its current draft will be restored to HEAD. Staged and unstaged changes will be discarded.")
        }
        .sheet(item: $model.pendingLatexRootSelection) { request in
            LatexRootSelectionView(request: request)
                .environmentObject(model)
        }
        .sheet(item: $model.pendingLatexExternalDependencies) { request in
            LatexExternalDependencyView(request: request)
                .environmentObject(model)
        }
    }
}
