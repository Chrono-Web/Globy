import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var mascot: MascotWindowController!
    private var clickThroughItem: NSMenuItem!
    private var permanenceItem: NSMenuItem!
    private var soundItem: NSMenuItem!
    private var liveItem: NSMenuItem!
    private var surfaceItems: [NSMenuItem] = []
    private static let surfaceKey = "surface"
    private static let soundKey = "soundEnabled"
    private static let permanenceKey = "permanence"
    private static let greetedKey = "didGreet"
    private var skipAutoGreet = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        mascot = MascotWindowController()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe",
                                           accessibilityDescription: "Globy")

        let menu = NSMenu()
        menu.addItem(withTitle: "Simula nuovo VOX", action: #selector(summon), keyEquivalent: "n")
        menu.addItem(withTitle: "Simula raffica (3 VOX)", action: #selector(summonBurst), keyEquivalent: "b")
        menu.addItem(withTitle: "Saluta", action: #selector(greet), keyEquivalent: "g")
        let surfaceMenu = NSMenu()
        for surface in Surface.allCases {
            let item = surfaceMenu.addItem(withTitle: surface.title, action: #selector(chooseSurface(_:)), keyEquivalent: "")
            item.representedObject = surface.rawValue
            item.target = self
            surfaceItems.append(item)
        }
        menu.addItem(withTitle: "Superficie", action: nil, keyEquivalent: "").submenu = surfaceMenu
        permanenceItem = menu.addItem(withTitle: "Permanenza", action: #selector(togglePermanence), keyEquivalent: "")
        clickThroughItem = menu.addItem(withTitle: "Click-through (buchi)", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.state = .on
        soundItem = menu.addItem(withTitle: "Suono", action: #selector(toggleSound), keyEquivalent: "")
        liveItem = menu.addItem(withTitle: "Ricarica alle modifiche", action: #selector(toggleLive), keyEquivalent: "")
        liveItem.state = LiveReload.isWatched ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu

        setSurface(UserDefaults.standard.string(forKey: Self.surfaceKey).flatMap(Surface.init) ?? Self.defaultSurface)
        mascot.soundEnabled = UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true
        soundItem.state = mascot.soundEnabled ? .on : .off
        mascot.permanence = UserDefaults.standard.bool(forKey: Self.permanenceKey)
        permanenceItem.state = mascot.permanence ? .on : .off

        applyCommandLine()
        if !skipAutoGreet, !UserDefaults.standard.bool(forKey: Self.greetedKey) {
            UserDefaults.standard.set(true, forKey: Self.greetedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.mascot.presentGreeting()
            }
        }
    }

    private static var defaultSurface: Surface {
        if #available(macOS 26, *) { return .liquidGlass }
        return .frosted
    }

    private func applyCommandLine() {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            skipAutoGreet = true
            let renderer = ImageRenderer(content: SnapshotSheet())
            renderer.scale = 2
            if let cg = renderer.cgImage,
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--demo") {
            skipAutoGreet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.summon() }
        }
        if CommandLine.arguments.contains("--burst") {
            skipAutoGreet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.summonBurst() }
        }
        if CommandLine.arguments.contains("--greet") {
            skipAutoGreet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.mascot.presentGreeting() }
        }
    }

    @objc private func summon() {
        mascot.summon(vox: .sample)
    }

    @objc private func summonBurst() {
        mascot.summonBurst(Vox.burst)
    }

    @objc private func greet() {
        mascot.presentGreeting()
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

    @objc private func togglePermanence() {
        mascot.permanence.toggle()
        permanenceItem.state = mascot.permanence ? .on : .off
        UserDefaults.standard.set(mascot.permanence, forKey: Self.permanenceKey)
    }

    @objc private func toggleClickThrough() {
        mascot.clickThrough.toggle()
        clickThroughItem.state = mascot.clickThrough ? .on : .off
    }

    @objc private func toggleSound() {
        mascot.soundEnabled.toggle()
        soundItem.state = mascot.soundEnabled ? .on : .off
        UserDefaults.standard.set(mascot.soundEnabled, forKey: Self.soundKey)
    }

    @objc private func toggleLive() {
        if LiveReload.isWatched {
            LiveReload.stopExternalWatch()
            liveItem.state = .off
            return
        }
        do {
            try LiveReload.startExternalWatch()
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Ricarica alle modifiche"
            alert.informativeText = "Non riesco ad avviare il watch. Serve watchexec (brew install watchexec)."
            alert.runModal()
        }
    }
}
