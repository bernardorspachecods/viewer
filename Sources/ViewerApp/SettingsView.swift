import ViewerCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            ZoomSettingsView()
                .tabItem {
                    Label("Zoom", systemImage: "textformat.size")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            WorkspacesSettingsView()
                .tabItem {
                    Label("Workspaces", systemImage: "folder")
                }

            WindowSizeSettingsView(session: model.workspaceSession)
                .tabItem {
                    Label("Windows", systemImage: "macwindow")
                }

            FilesSettingsView()
                .tabItem {
                    Label("Files", systemImage: "doc.on.doc")
                }

            LatexSettingsView()
                .tabItem {
                    Label("LaTeX", systemImage: "doc.text")
                }
        }
        .frame(width: 540)
        .frame(minHeight: 380)
    }
}

private struct ZoomSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Default Zoom") {
                ZoomPreferenceRow(
                    title: "Markdown",
                    value: Binding(
                        get: { model.defaultMarkdownZoom },
                        set: { model.setDefaultMarkdownZoom($0) }
                    )
                )
                ZoomPreferenceRow(
                    title: "LaTeX / PDF",
                    value: Binding(
                        get: { model.defaultLatexZoom },
                        set: { model.setDefaultLatexZoom($0) }
                    )
                )
            }

            Text("Applies to documents without an individually saved zoom level.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(TextWidthPreference.key) private var limitsTextWidth = TextWidthPreference.defaultLimitsTextWidth

    var body: some View {
        Form {
            Section("Theme") {
                Picker(
                    "Theme",
                    selection: Binding(
                        get: { model.theme },
                        set: { model.setTheme($0) }
                    )
                ) {
                    ForEach(AppThemePreference.allCases) { preference in
                        Text(preference.label).tag(preference)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Markdown Text Width") {
                Toggle("Keep text in a reading column", isOn: $limitsTextWidth)
                Text("Off: the text of the preview and the editor runs to the window edges. On: it stays in a centered column.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("You can also quickly toggle the theme with ⌥⌘T.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct FilesSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newExtension = ""
    @State private var extensionError: String?

    var body: some View {
        Form {
            Section("Supported by Viewer") {
                ForEach(DocumentKind.selectableKinds, id: \.self) { kind in
                    Toggle(
                        kind.label,
                        isOn: Binding(
                            get: { model.selectedFileKinds.contains(kind) },
                            set: { model.setFileKind(kind, selected: $0) }
                        )
                    )
                }
            }

            Section {
                ForEach(model.extraFileExtensions, id: \.self) { ext in
                    HStack {
                        Text(".\(ext)")
                        Spacer()
                        Button {
                            model.removeExtraFileExtension(ext)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove .\(ext)")
                    }
                }
                HStack(alignment: .center, spacing: 8) {
                    TextField("Extension", text: $newExtension, prompt: Text("Extension, e.g. txt"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addExtension)
                    Button("Add", action: addExtension)
                }
                if let extensionError {
                    Text(extensionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Other types (open in the default app)")
            } footer: {
                Text("\"Show selected files only\" in the sidebar options menu shows only these file types. Folders stay when they contain a shown file. Supported types are previewed or edited in Viewer; other types you add are listed in the tree and open in the macOS default app.")
            }

        }
        .formStyle(.grouped)
        .padding()
    }

    private func addExtension() {
        let raw = newExtension
        if model.addExtraFileExtension(raw) {
            newExtension = ""
            extensionError = nil
        } else {
            extensionError = "Invalid, already supported by Viewer, or already added."
        }
    }
}

private extension LaunchBehavior {
    var settingsLabel: String {
        switch self {
        case .reopenLast: "Reopen the last workspaces"
        case .alwaysDefaults: "Always open the default workspaces"
        }
    }
}

private struct WorkspacesSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("On Launch") {
                Picker(
                    "When Viewer starts",
                    selection: Binding(
                        get: { model.launchBehavior },
                        set: { model.setLaunchBehavior($0) }
                    )
                ) {
                    ForEach(LaunchBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.settingsLabel).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Default Workspaces") {
                if model.defaultWorkspaceFolders.isEmpty {
                    Text("No folders added. Viewer opens your home folder.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.defaultWorkspaceFolders, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                            Spacer()
                            Button {
                                model.removeDefaultWorkspaceFolder(path: path)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(URL(fileURLWithPath: path).lastPathComponent)")
                        }
                    }
                }

                Button("Add Folder…", action: chooseFolder)
            }

            Text("Opened when Viewer has no previous session to reopen, or on every launch if you choose Always open the default workspaces. Empty = your home folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.addDefaultWorkspaceFolder(url.resolvingSymlinksInPath().standardizedFileURL)
    }
}

private struct LatexSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Compilation") {
                Picker(
                    "Shell escape",
                    selection: Binding(
                        get: { model.latexShellEscapeMode },
                        set: { model.setLatexShellEscapeMode($0) }
                    )
                ) {
                    ForEach(LatexShellEscapeMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            Label(
                "Shell escape can allow the LaTeX process to run external commands. Enable it only for documents you trust.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ZoomPreferenceRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 96, alignment: .leading)
            Spacer()
            HStack(spacing: 5) {
                ZoomValueControl(value: $value)
                Text("%")
                    .foregroundStyle(.secondary)
                    .frame(width: 12, alignment: .leading)
            }
        }
    }
}

private struct ZoomValueControl: View {
    @Binding var value: Double
    @FocusState private var isFocused: Bool

    private var percentageValue: Binding<Double> {
        Binding(
            get: { value * 100 },
            set: { value = DocumentZoomLimits.clamped($0 / 100) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            TextField(
                "",
                value: percentageValue,
                format: .number.precision(.fractionLength(0))
            )
            .focused($isFocused)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.plain)
            .padding(.leading, 7)
            .padding(.trailing, 3)
            .frame(width: 64, height: 24)
            .monospacedDigit()

            VStack(spacing: 0) {
                Button {
                    adjust(by: 0.1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 18, height: 11)
                        .iconButtonHitArea()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Zoom In")

                Button {
                    adjust(by: -0.1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 18, height: 11)
                        .iconButtonHitArea()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Zoom Out")
            }
            .frame(width: 18, height: 24)
        }
        .frame(width: 82, height: 24)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isFocused ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isFocused ? 2 : 1
                )
        }
    }

    private func adjust(by amount: Double) {
        value = DocumentZoomLimits.clamped(value + amount)
    }
}
