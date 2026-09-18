import AppKit
import Combine
import SwiftUI

/// Globo nella barra dei menu e pannelli vetro (elenco e preferenze).
/// Niente `MenuBarExtra`/`Settings`: su un'app accessoria producono il fondo nero,
/// la finestra brutta in alto e gli errori `linkd.autoShortcut`.
@MainActor
final class StatusItemController: NSObject {
    private let session: AppSession
    private let updates: UpdateController
    private let item: NSStatusItem
    private let panel: MenuPanel
    private let host: NSHostingView<MenuBarView>
    private var prefs: NSWindow?
    private var prefsHost: NSHostingView<SettingsView>?
    private var outsideMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables: [AnyCancellable] = []
    private let updateDot = UpdateDotView()

    init(session: AppSession, updates: UpdateController) {
        self.session = session
        self.updates = updates
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = MenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        host = NSHostingView(rootView: MenuBarView(session: session, updates: updates, onPreferences: {}, onDismiss: {}))
        super.init()
        configureStatusItem()
        session.mascot.onOpenPreferences = { [weak self] in self?.showPreferences() }
        configurePanel()
        session.objectWillChange
            .sink { [weak self] _ in
                // `objectWillChange` arriva prima del cambiamento: misura al giro successivo.
                DispatchQueue.main.async {
                    self?.relayoutIfVisible()
                    self?.refreshStatusAccessibility()
                }
            }
            .store(in: &cancellables)
        updates.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.relayoutIfVisible()
                    self?.refreshStatusAccessibility()
                }
            }
            .store(in: &cancellables)
        // Tornando da «notifiche di sistema» con le Impostazioni aperte, torna l'anteprima.
        session.preferences.$mascotEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self, enabled, self.prefs?.isVisible == true else { return }
                DispatchQueue.main.async { self.session.mascot.showPreview() }
            }
            .store(in: &cancellables)
    }

    @objc func togglePopover(_ sender: Any?) {
        if panel.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPreferences() {
        closePopover()
        if prefs == nil {
            prefs = makePreferencesWindow()
        }
        // Finché le Impostazioni sono aperte Globy si comporta da app normale: Dock, ⌘Tab, menu.
        NSApp.setActivationPolicy(.regular)
        if prefs?.isVisible == false {
            prefs?.center()
        }
        prefs?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if session.preferences.mascotEnabled {
            session.mascot.showPreview()
        }
    }

    private func configureStatusItem() {
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Globy")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        updateDot.translatesAutoresizingMaskIntoConstraints = false
        updateDot.isHidden = true
        button.addSubview(updateDot)
        // In basso a destra del globo, dove non copre il disegno delle meridiane.
        NSLayoutConstraint.activate([
            updateDot.widthAnchor.constraint(equalToConstant: UpdateDotView.size),
            updateDot.heightAnchor.constraint(equalToConstant: UpdateDotView.size),
            updateDot.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 6),
            updateDot.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 5),
        ])
        refreshStatusAccessibility()
    }

    private func refreshStatusAccessibility() {
        let unread = session.unreadCount
        var label = unread == 0 ? "Globy" : (unread == 1 ? "Globy, 1 VOX non letto" : "Globy, \(unread) VOX non letti")
        if updates.hasUpdate {
            label += ", aggiornamento disponibile"
        }
        item.button?.setAccessibilityLabel(label)
        updateDot.isHidden = !updates.hasUpdate
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // L'ombra di finestra segue il rettangolo, non gli angoli del vetro: disegnava un bordo squadrato.
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        host.rootView = MenuBarView(
            session: session,
            updates: updates,
            onPreferences: { [weak self] in self?.showPreferences() },
            onDismiss: { [weak self] in self?.closePopover() }
        )
        // Dimensioni decise da `relayout()`, non dai vincoli: evita il pannello bloccato e tagliato.
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]

        // Il contenuto sta dentro il vetro, come vuole `NSGlassEffectView`.
        let glass = GlassPanelView.makeNSView(surface: Self.surface)
        glass.autoresizingMask = [.width, .height]
        if #available(macOS 26, *), let effect = glass as? NSGlassEffectView {
            effect.cornerRadius = Self.cornerRadius
            effect.contentView = host
        } else if let blur = glass as? NSVisualEffectView {
            blur.material = .popover
            blur.wantsLayer = true
            blur.layer?.cornerRadius = Self.cornerRadius
            blur.layer?.masksToBounds = true
            blur.addSubview(host)
        }
        panel.contentView = glass
    }

    private func showPopover() {
        relayout()
        guard let button = item.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = CGPoint(
            x: buttonRect.midX - panel.frame.width / 2,
            y: buttonRect.minY - panel.frame.height - 6
        )
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panel.frame.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }
        panel.setFrameOrigin(origin)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startMonitors()
    }

    private func closePopover() {
        stopMonitors()
        panel.orderOut(nil)
    }

    private func relayoutIfVisible() {
        guard panel.isVisible else { return }
        let top = panel.frame.maxY
        relayout()
        var frame = panel.frame
        frame.origin.y = top - frame.height
        panel.setFrame(frame, display: true)
    }

    /// Adatta il pannello al contenuto SwiftUI, entro l'area visibile dello schermo.
    private func relayout() {
        let maxHeight = ((item.button?.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 800) - 24
        let proposal = NSSize(width: MenuBarView.width + 2 * Self.inset, height: .greatestFiniteMagnitude)
        var size = NSHostingController(rootView: host.rootView).sizeThatFits(in: proposal)
        size.width = MenuBarView.width + 2 * Self.inset
        size.height = min(max(ceil(size.height), 60), maxHeight)
        panel.setContentSize(size)
        host.frame = NSRect(origin: .zero, size: size)
    }

    private func startMonitors() {
        stopMonitors()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeIfClickOutside()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePopover()
                return nil
            }
            return event
        }
    }

    private func closeIfClickOutside() {
        let point = NSEvent.mouseLocation
        if panel.frame.contains(point) { return }
        if let button = item.button, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            if rect.contains(point) { return }
        }
        closePopover()
    }

    private func stopMonitors() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        outsideMonitor = nil
        keyMonitor = nil
    }

    private func makePreferencesWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: SettingsView(session: session, updates: updates))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni di Globy"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        prefsHost = hosting
        return window
    }

    private static var surface: Surface { .systemDefault }
    private static let cornerRadius: CGFloat = 16
    private static let inset: CGFloat = 6
}

/// Pallino dell'aggiornamento sopra il globo: una vista a parte, così l'icona resta
/// un'immagine template e segue da sola barra chiara, scura e con sfondo colorato.
private final class UpdateDotView: NSView {
    static let size: CGFloat = 7

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = Self.size / 2
        layer?.backgroundColor = NSColor.systemOrange.cgColor
    }

    // Il clic passa al pulsante sotto.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Un pannello senza bordi non diventa key da solo: servono tastiera, hover e pulsante predefinito.
private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

extension StatusItemController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === prefs else { return }
        session.mascot.hidePreview()
        NSApp.setActivationPolicy(.accessory)
    }
}
