import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var mascot: MascotWindowController!
    private var clickThroughItem: NSMenuItem!
    private var alwaysOnItem: NSMenuItem!
    private var surfaceItems: [NSMenuItem] = []
    private static let alwaysOnKey = "alwaysOn"
    private static let surfaceKey = "surface"

    func applicationDidFinishLaunching(_ notification: Notification) {
        mascot = MascotWindowController()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe",
                                           accessibilityDescription: "Globy")

        let menu = NSMenu()
        menu.addItem(withTitle: "Simula nuova VOX", action: #selector(summon), keyEquivalent: "n")
        alwaysOnItem = menu.addItem(withTitle: "Sempre presente", action: #selector(toggleAlwaysOn), keyEquivalent: "")
        let surfaceMenu = NSMenu()
        for surface in Surface.allCases {
            let item = surfaceMenu.addItem(withTitle: surface.title, action: #selector(chooseSurface(_:)), keyEquivalent: "")
            item.representedObject = surface.rawValue
            item.target = self
            surfaceItems.append(item)
        }
        menu.addItem(withTitle: "Superficie", action: nil, keyEquivalent: "").submenu = surfaceMenu
        clickThroughItem = menu.addItem(withTitle: "Click-through", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.state = .on
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu

        setSurface(UserDefaults.standard.string(forKey: Self.surfaceKey).flatMap(Surface.init) ?? .dark)
        if UserDefaults.standard.bool(forKey: Self.alwaysOnKey) {
            setAlwaysOn(true)
        }

        // --snapshot <file.png>: esporta il globo senza finestre, per controlli senza schermo.
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            let renderer = ImageRenderer(content: SnapshotSheet())
            renderer.scale = 2
            if let cg = renderer.cgImage,
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
            NSApp.terminate(nil)
        }

        if CommandLine.arguments.contains("--demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.summon() }
        }
    }

    @objc private func summon() {
        mascot.summon(vox: .sample)
    }

    @objc private func toggleAlwaysOn() {
        setAlwaysOn(!mascot.alwaysOn)
    }

    private func setAlwaysOn(_ on: Bool) {
        mascot.alwaysOn = on
        alwaysOnItem.state = on ? .on : .off
        UserDefaults.standard.set(on, forKey: Self.alwaysOnKey)
    }

    @objc private func chooseSurface(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let surface = Surface(rawValue: raw) else { return }
        setSurface(surface)
    }

    private func setSurface(_ surface: Surface) {
        mascot.surface = surface
        for item in surfaceItems {
            item.state = item.representedObject as? String == surface.rawValue ? .on : .off
        }
        UserDefaults.standard.set(surface.rawValue, forKey: Self.surfaceKey)
    }

    @objc private func toggleClickThrough() {
        mascot.clickThrough.toggle()
        clickThroughItem.state = mascot.clickThrough ? .on : .off
    }
}
