import AppKit
import SwiftUI

/// Finestra trasparente, non attivante, presente su tutti gli Space e sopra il fullscreen.
@MainActor
final class MascotWindowController {
    /// Finestra: globo nell'angolo in basso a destra, fumetto della VOX sopra.
    static let size = CGSize(width: 360, height: 500)
    static let globeArea = CGSize(width: 160, height: 160)
    /// Distanza del fumetto dal bordo destro e dal riquadro del globo (negativa: il globo
    /// disegnato è più piccolo del suo riquadro).
    static let cardTrailing: CGFloat = 12
    static let cardGap: CGFloat = -12
    /// Quanto resta a schermo il fumetto dopo che il globo ha finito di leggere.
    static let voxLinger: TimeInterval = 6
    static let margin: CGFloat = 16

    private let panel: NSPanel
    private let model = MascotModel()
    private var hideWork: DispatchWorkItem?

    /// Modalità sempre presente: il globo resta a schermo e reagisce alle nuove VOX.
    var alwaysOn = false {
        didSet {
            guard alwaysOn != oldValue else { return }
            hideWork?.cancel()
            if alwaysOn {
                show()
            } else {
                dismiss()
            }
        }
    }

    var surface: Surface {
        get { model.surface }
        set { model.surface = newValue }
    }

    var clickThrough = true {
        didSet {
            panel.ignoresMouseEvents = clickThrough
            panel.isMovableByWindowBackground = !clickThrough
        }
    }

    init() {
        panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        model.windowFrame = { [unowned panel] in panel.frame }
        let host = NSHostingView(rootView: MascotView(model: model))
        host.frame = CGRect(origin: .zero, size: Self.size)
        panel.contentView = host

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Nuova VOX: il globo entra (o, se già a schermo, saluta con un doppio battito) e
    /// mostra la card. Un richiamo durante una presenza in corso prolunga l'attesa invece
    /// di duplicare il globo. In modalità sempre presente scompare solo la card.
    func summon(vox: Vox) {
        hideWork?.cancel()
        if !show() { model.greet() }
        let readingDone = model.present(vox)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.alwaysOn ? self.model.dismissVox() : self.dismiss()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + readingDone + Self.voxLinger, execute: work)
    }

    /// Restituisce `true` se il globo stava entrando in scena.
    @discardableResult
    private func show() -> Bool {
        guard model.phase == .hidden || model.phase == .leaving else { return false }
        reposition()
        panel.orderFrontRegardless()
        model.enter()
        return true
    }

    private func dismiss() {
        model.leave { [weak self] in
            // Nascosta: niente finestra a schermo, TimelineView in pausa.
            self?.panel.orderOut(nil)
        }
    }

    /// Angolo inferiore destro dell'area visibile dello schermo su cui si trova il puntatore.
    private func reposition() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = CGPoint(x: visible.maxX - Self.size.width - Self.margin,
                             y: visible.minY + Self.margin)
        panel.setFrameOrigin(origin)
    }
}
