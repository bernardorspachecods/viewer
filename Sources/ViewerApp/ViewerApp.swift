import ViewerCore
import AppKit
import SwiftUI

@main
@MainActor
struct ViewerApp: App {
    @NSApplicationDelegateAdaptor(ViewerAppDelegate.self) private var appDelegate
    @StateObject private var windowManager: WorkspaceWindowManager
    @StateObject private var model: AppModel

    init() {
        let windowManager = WorkspaceWindowManager.shared
        _windowManager = StateObject(wrappedValue: windowManager)
        let model = AppModel(workspaceSession: windowManager.session)
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        Window("Viewer", id: "main") {
            RootView()
                .environmentObject(model)
        }
        .defaultSize(
            width: WorkspaceWindowMetrics.defaultWidth,
            height: WorkspaceWindowMetrics.defaultHeight
        )
        .restorationBehavior(.disabled)
        .commands {
            MainWindowCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Markdown File") {
                    windowManager.modelForActiveWindow(fallback: model)?.createNewMarkdownDocument()
                }
                    .appShortcut(AppShortcuts.newMarkdownFile)

                Button("New Workspace…") {
                    windowManager.chooseAndOpenWorkspace(
                        from: windowManager.modelForActiveWindow(fallback: model)
                    )
                }
                    .appShortcut(AppShortcuts.newWorkspace)

                Button("Open Folder…") {
                    windowManager.chooseAndOpenWorkspace(
                        from: windowManager.modelForActiveWindow(fallback: model)
                    )
                }
                    .appShortcut(AppShortcuts.openFolder)
            }

            CommandMenu("View") {
                Button("Refresh Preview") {
                    windowManager.modelForActiveWindow(fallback: model)?.refreshActiveTab()
                }
                    .appShortcut(AppShortcuts.refreshPreview)

                    Button("Find in Document") {
                        windowManager.modelForActiveWindow(fallback: model)?.showFindBar()
                    }
                    .appShortcut(AppShortcuts.findInDocument)

                Button("Zoom In") {
                    windowManager.modelForActiveWindow(fallback: model)?.zoomIn()
                }
                    .appShortcut(AppShortcuts.zoomIn)

                Button("Zoom Out") {
                    windowManager.modelForActiveWindow(fallback: model)?.zoomOut()
                }
                    .appShortcut(AppShortcuts.zoomOut)

                Button("Reset Zoom") {
                    windowManager.modelForActiveWindow(fallback: model)?.resetPreviewZoom()
                }
                    .appShortcut(AppShortcuts.resetZoom)

                Button("Toggle Sidebar") {
                    guard let activeModel = windowManager.modelForActiveWindow(fallback: model) else { return }
                    activeModel.setSidebarVisible(!activeModel.sidebarVisible)
                }
                    .appShortcut(AppShortcuts.toggleSidebar)

                Button("Focus Mode") {
                    windowManager.modelForActiveWindow(fallback: model)?.toggleFocusMode()
                }
                .appShortcut(AppShortcuts.focusMode)

                Button("Toggle Theme") {
                    windowManager.modelForActiveWindow(fallback: model)?.cycleTheme()
                }
                    .appShortcut(AppShortcuts.toggleTheme)
            }

            CommandGroup(replacing: .windowArrangement) {
                Button("Close Tab") {
                    windowManager.closeActiveTabInKeyWindow()
                }
                .appShortcut(AppShortcuts.closeTab)
            }

            CommandMenu("Tabs") {
                    Button("Next Tab") {
                        windowManager.modelForActiveWindow(fallback: model)?.selectNextTab()
                    }
                    .appShortcut(AppShortcuts.nextTab)

                ForEach(Array((windowManager.activeModel ?? model).tabs.prefix(9).enumerated()), id: \.element.id) { index, tab in
                    Button("\(index + 1): \(tab.title)") {
                        windowManager.modelForActiveWindow(fallback: model)?.selectTab(number: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: AppShortcuts.selectTab.menuModifiers)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(windowManager.activeModel ?? model)
        }
    }
}

/// Hands the delegate a way to open the main window, which SwiftUI does not
/// create when the app is launched only to open files.
struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        let _ = WorkspaceWindowManager.shared.openMainWindow = { openWindow(id: "main") }
        CommandGroup(after: .windowArrangement) {
            Button("Show Workspace Window") {
                openWindow(id: "main")
            }
        }
    }
}

@MainActor
final class ViewerAppDelegate: NSObject, NSApplicationDelegate {
    private var localKeyMonitor: Any?
    private var replyCapture: TerminalReplyController?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        WorkspaceWindowManager.shared.prepareForTermination()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // SwiftUI's own handler closes the main Window scene on every open
        // event. Handle the event here so reader windows leave it untouched.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    @objc private func handleOpenDocuments(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let direct = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
        let items = direct.numberOfItems > 0 ? (1...direct.numberOfItems).compactMap { direct.atIndex($0) } : [direct]
        let urls = items.compactMap { item -> URL? in
            guard let data = item.coerce(toDescriptorType: DescType(typeFileURL))?.data else { return nil }
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        routeOpenedFiles(urls)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let captureController = TerminalReplyController(windows: WorkspaceWindowManager.shared)
        replyCapture = captureController
        captureController.registerGlobalShortcut()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == [.command],
                  event.charactersIgnoringModifiers?.lowercased() == "w" else {
                return event
            }

            Task { @MainActor in
                WorkspaceWindowManager.shared.closeActiveTabInKeyWindow()
            }
            return nil
        }

        NSWindow.allowsAutomaticWindowTabbing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            WorkspaceWindowManager.shared.ensureWorkspaceWindow()
        }
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        replyCapture?.unregisterGlobalShortcut()
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        routeOpenedFiles(filenames.map { URL(fileURLWithPath: $0) })
        application.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        routeOpenedFiles(urls)
    }

    /// Markdown files opened from outside the app (Finder, `open`) get their own
    /// reader window, like the captured-reply shortcut. Other kinds keep opening
    /// in the focused workspace.
    private func routeOpenedFiles(_ urls: [URL]) {
        let markdown = urls.filter { $0.isFileURL && DocumentKind(url: $0) == .markdown }
        let others = urls.filter { !markdown.contains($0) }
        if !markdown.isEmpty {
            WorkspaceWindowManager.shared.openReaderWindows(for: markdown)
        }
        if !others.isEmpty {
            NotificationCenter.default.post(name: .viewerOpenFiles, object: others)
        }
    }
}
