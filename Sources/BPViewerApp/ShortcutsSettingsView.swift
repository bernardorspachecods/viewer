import BPViewerCore
import SwiftUI

/// The Shortcuts tab. Lists `AppShortcuts.sections`, the same values the menu
/// commands bind, so this list cannot drift from the real shortcuts.
struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            ForEach(AppShortcuts.sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.shortcuts, id: \.title) { shortcut in
                        ShortcutRow(title: shortcut.title, shortcut: shortcut.display)
                    }
                }
            }

            Text("Shortcuts are defined by the app and cannot be edited in this version.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
