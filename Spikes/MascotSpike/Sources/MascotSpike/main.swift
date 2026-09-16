import AppKit

// Spike usa e getta: niente sincronizzazione, il richiamo è manuale dal menu.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
