import AppKit
import SwiftUI

/// Avvio AppKit: niente `MenuBarExtra` né scena Settings.
@main
enum GlobyMain {
    nonisolated(unsafe) private static var delegate: GlobyAppDelegate?

    static func main() {
        // Una sola copia di Globy: due globi e due sincronizzazioni si pesterebbero i piedi.
        let runningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !runningTests, let bundleId = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
               .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            return
        }
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
    let updates = UpdateController()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = StatusItemController(session: session, updates: updates)
        statusItem = controller
        updates.onShowPreferences = { [weak controller] in controller?.showPreferences() }
        updates.onAnnounce = { [session, updates, weak controller] version in
            // Con Globy a schermo lo dice lui; in modalità notifiche di sistema, il Mac.
            guard session.preferences.mascotEnabled else {
                session.notifications.postUpdate(version: version)
                return true
            }
            guard !session.mascot.isBusy else { return false }
            let text = "È uscita una nuova versione di me, la \(version)! Vuoi che mi aggiorni? Ci metto un attimo e poi torno qui."
            session.mascot.presentGreeting(.welcome(text, asksChoice: true, yesTitle: "Aggiornati", noTitle: "Più tardi")) { [weak controller] outcome in
                guard outcome == .accepted else { return }
                updates.install()
                controller?.showPreferences()
            }
            return true
        }
        session.notifications.onOpenUpdate = { [weak controller] in controller?.showPreferences() }
        session.start()
        updates.start()
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
        if let i = CommandLine.arguments.firstIndex(of: "--render-icon"), i + 1 < CommandLine.arguments.count {
            let renderer = ImageRenderer(content: AppIconArt())
            renderer.scale = 1
            if let cg = renderer.cgImage,
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
            NSApp.terminate(nil)
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
