import SwiftUI
import ViewerCore

struct WindowSizeSettingsView: View {
    private let session: WorkspaceSessionCoordinator
    @State private var saved: WindowOpeningPreferences
    @State private var remembersWorkspaceSize: Bool
    @State private var workspace: WindowSizeInput
    @State private var reader: WindowSizeInput

    init(session: WorkspaceSessionCoordinator) {
        self.session = session
        let preferences = session.windowOpeningPreferences
        _saved = State(initialValue: preferences)
        _remembersWorkspaceSize = State(initialValue: preferences.remembersWorkspaceSize)
        _workspace = State(initialValue: WindowSizeInput(preferences.workspace))
        _reader = State(initialValue: WindowSizeInput(preferences.reader))
    }

    private var editedPreferences: WindowOpeningPreferences? {
        guard let readerSize = reader.size,
              remembersWorkspaceSize || workspace.size != nil else { return nil }
        return WindowOpeningPreferences(
            remembersWorkspaceSize: remembersWorkspaceSize,
            workspace: workspace.size ?? saved.workspace,
            reader: readerSize
        )
    }

    var body: some View {
        Form {
            Section("Workspace Window") {
                Picker("Opening size", selection: $remembersWorkspaceSize) {
                    Text("Remember last size").tag(true)
                    Text("Use custom size").tag(false)
                }
                if !remembersWorkspaceSize {
                    WindowDimensionsFields(input: $workspace)
                }
            }

            Section("Reply Reader (⇧⌘E)") {
                WindowDimensionsFields(input: $reader)
            }

            LabeledContent {
                Button("Apply", action: apply)
                    .disabled(editedPreferences == nil || editedPreferences == saved)
            } label: {
                if editedPreferences == nil {
                    let minimum = WindowOpeningSize.minimum
                    Text("Enter whole numbers. Minimum: \(minimum.width) × \(minimum.height) pt.")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func apply() {
        guard let preferences = editedPreferences else { return }
        session.setWindowOpeningPreferences(preferences)
        saved = preferences
    }
}

private struct WindowDimensionsFields: View {
    @Binding var input: WindowSizeInput

    var body: some View {
        TextField("Width (pt)", text: $input.width)
        TextField("Height (pt)", text: $input.height)
    }
}

private struct WindowSizeInput {
    var width: String
    var height: String

    init(_ size: WindowOpeningSize) {
        width = String(size.width)
        height = String(size.height)
    }

    var size: WindowOpeningSize? {
        guard let width = Int(width), let height = Int(height) else { return nil }
        let size = WindowOpeningSize(width: width, height: height)
        return size.meetsMinimum ? size : nil
    }
}
