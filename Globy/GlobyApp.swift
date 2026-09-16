import AppKit

/// Avvio AppKit: niente `MenuBarExtra` né scena Settings.
@main
enum GlobyMain {
    nonisolated(unsafe) private static var delegate: GlobyAppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = GlobyAppDelegate()
        self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class GlobyAppDelegate: NSObject, NSApplicationDelegate {
    let session = AppSession()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(session: session)
        session.start()
        #if DEBUG
        if CommandLine.arguments.contains("--open-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.statusItem?.togglePopover(nil)
            }
        }
        if CommandLine.arguments.contains("--open-preferences") {
            statusItem?.showPreferences()
        }
        if let i = CommandLine.arguments.firstIndex(of: "--simulate-return"),
           i + 1 < CommandLine.arguments.count, let count = Int(CommandLine.arguments[i + 1]) {
            Task { [session] in
                try? await Task.sleep(for: .seconds(2))
                await session.simulateReturn(newVoxCount: count)
            }
        }
        if CommandLine.arguments.contains("--publish-silently") {
            Task { [session] in
                try? await Task.sleep(for: .seconds(3))
                await session.publishWithoutSync()
            }
        }
        if CommandLine.arguments.contains("--simulate-vox") {
            Task { [session] in await session.simulatePublication() }
        }
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }
}
