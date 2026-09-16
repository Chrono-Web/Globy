import AppKit
import SwiftUI

/// Finestra trasparente, non attivante, presente su tutti gli Space e sopra il fullscreen.
@MainActor
final class MascotWindowController {
    /// Finestra: globo nell'angolo in basso a destra, fumetto della VOX sopra.
    static let size = CGSize(width: 360, height: 512)
    static let globeArea = CGSize(width: 160, height: 160)
    static let globeDrawn: CGFloat = 116
    /// Distanza del fumetto dal bordo destro e dal riquadro del globo (negativa: il globo
    /// disegnato è più piccolo del suo riquadro).
    static let cardTrailing: CGFloat = 12
    static let cardGap: CGFloat = -12
    /// Quanto resta a schermo il fumetto dopo che il globo ha finito di leggere.
    static let voxLinger: TimeInterval = 6
    static let queuePause: TimeInterval = 1
    static let dragGrace: TimeInterval = 5
    static let margin: CGFloat = 16

    private let panel: NSPanel
    private let model = MascotModel()
    private let closeButton = VoxCornerButton(frame: .zero, tooltip: "Chiudi", accessibilityLabel: "Chiudi")
    private let nextButton = VoxCornerButton(frame: .zero, tooltip: "VOX successiva", accessibilityLabel: "VOX successiva")
    private let backButton = VoxCornerButton(frame: .zero, tooltip: "VOX precedente", accessibilityLabel: "VOX precedente")
    private let hitView = MascotHitView(frame: .zero)
    private var hideWork: DispatchWorkItem?
    private var hideDeadline: TimeInterval?
    private var mouseMonitors: [Any] = []
    private var queue: [Vox] = []
    /// VOX già mostrate in questa sessione, per la freccia indietro.
    private var history: [Vox] = []
    private var current: Vox?
    /// Fumetto di saluto: non è in coda e non è una VOX.
    private var showingGreeting = false
    private var movedThisAppearance = false

    var surface: Surface {
        get { model.surface }
        set { model.surface = newValue }
    }

    var soundEnabled = true

    /// Se attiva, il globo resta a schermo come prima: la X chiude solo il fumetto.
    /// Se disattiva, dopo un trascinamento restano 5 secondi in più prima di scomparire.
    var permanence = false {
        didSet {
            guard permanence != oldValue else { return }
            if permanence {
                cancelHide()
                _ = show()
            } else if model.reading == nil {
                dismiss()
            } else {
                scheduleHide(after: Self.voxLinger)
            }
        }
    }

    var clickThrough = true {
        didSet { updateIgnoresMouseEvents() }
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
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false

        model.windowFrame = { [unowned panel] in panel.frame }

        let root = NSView(frame: CGRect(origin: .zero, size: Self.size))
        let host = NSHostingView(rootView: MascotView(model: model))
        host.frame = root.bounds
        host.autoresizingMask = [.width, .height]
        hitView.autoresizingMask = [.width, .height]
        hitView.frame = root.bounds
        hitView.onClick = { [weak self] in self?.openCurrent() }
        hitView.onDrag = { [weak self] event in self?.drag(with: event) }
        hitView.onDragEnd = { [weak self] in self?.extendHideAfterDrag() }
        hitView.isInteractive = { [weak self] point in self?.isInteractive(at: point) ?? false }
        closeButton.isHidden = true
        closeButton.action = { [weak self] in self?.closeVoxOnly() }
        nextButton.isHidden = true
        nextButton.action = { [weak self] in self?.goToNext() }
        backButton.isHidden = true
        backButton.action = { [weak self] in self?.goToPrevious() }
        root.addSubview(host)
        root.addSubview(hitView)
        root.addSubview(closeButton)
        root.addSubview(nextButton)
        root.addSubview(backButton)
        panel.contentView = root

        model.onUserDismiss = { [weak self] in self?.closeVoxOnly() }
        model.onCardChange = { [weak self] in self?.syncCornerButtons() }

        startMouseTracking()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.repositionIfNeeded() }
        }
    }

    /// Accoda una VOX. Se il globo è nascosto, parte il richiamo; se sta già leggendo,
    /// le successive aspettano con una pausa di un secondo tra una e l'altra.
    func summon(vox: Vox) {
        queue.append(vox)
        if current == nil, !showingGreeting {
            presentNext(fromHidden: true)
        } else {
            refreshChrome()
        }
    }

    func summonBurst(_ items: [Vox]) {
        items.forEach(summon)
    }

    /// Saluto di carattere: occhi sorridenti, niente coda, niente permalink.
    func presentGreeting() {
        showingGreeting = true
        model.setSmiling(true)
        if model.phase == .hidden || model.phase == .leaving {
            movedThisAppearance = false
            if !show() { model.greet() }
        } else {
            model.greet()
        }
        playSoundIfAllowed()
        refreshChrome()
        let readingDone = model.present(.greeting)
        if permanence {
            cancelHide()
        } else {
            scheduleHide(after: readingDone + Self.voxLinger)
        }
    }

    /// Clic su globo o fumetto: apre la VOX visibile su Chronocol, senza cambiare coda.
    private func openCurrent() {
        guard !showingGreeting, let current else { return }
        NSWorkspace.shared.open(current.permalink)
    }

    /// X: chiude solo il fumetto. Il globo resta se c'è la permanenza.
    private func closeVoxOnly() {
        if showingGreeting {
            endGreeting()
            return
        }
        if !queue.isEmpty { queue.removeFirst() }
        current = nil
        if queue.isEmpty { history.removeAll() }
        model.dismissVox()
        refreshChrome()
        if permanence {
            cancelHide()
        }
    }

    private func endGreeting() {
        showingGreeting = false
        model.setSmiling(false)
        model.dismissVox()
        if permanence {
            cancelHide()
        }
        if !queue.isEmpty {
            presentNext(fromHidden: false, playSound: false)
        } else {
            refreshChrome()
        }
    }

    /// Freccia in basso a destra: passa alla VOX successiva in coda.
    private func goToNext() {
        guard queue.count > 1, let shown = queue.first else { return }
        history.append(shown)
        queue.removeFirst()
        presentNext(fromHidden: false)
    }

    /// Freccia in basso a sinistra: torna alla VOX precedente.
    private func goToPrevious() {
        guard let previous = history.popLast() else { return }
        queue.insert(previous, at: 0)
        presentNext(fromHidden: false, playSound: false)
    }

    private func presentNext(fromHidden: Bool, playSound: Bool = true) {
        showingGreeting = false
        model.setSmiling(false)
        guard let vox = queue.first else {
            current = nil
            history.removeAll()
            refreshChrome()
            if !permanence { dismiss() }
            return
        }
        current = vox
        if fromHidden || model.phase == .hidden || model.phase == .leaving {
            movedThisAppearance = false
            if !show() { model.greet() }
        } else {
            model.greet()
        }
        if playSound { playSoundIfAllowed() }
        refreshChrome()
        let readingDone = model.present(vox)
        if permanence {
            cancelHide()
        } else {
            scheduleHide(after: readingDone + Self.voxLinger)
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelHide()
        let work = DispatchWorkItem { [weak self] in
            self?.hideTimerFired()
        }
        hideWork = work
        hideDeadline = Date.timeIntervalSinceReferenceDate + delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelHide() {
        hideWork?.cancel()
        hideWork = nil
        hideDeadline = nil
    }

    private func hideTimerFired() {
        hideDeadline = nil
        hideWork = nil
        if permanence { return }
        if showingGreeting {
            endGreeting()
            if current == nil { dismiss() }
            return
        }
        if model.reading != nil, queue.count > 1, let shown = queue.first {
            history.append(shown)
            queue.removeFirst()
            current = nil
            model.dismissVox()
            refreshChrome()
            let work = DispatchWorkItem { [weak self] in
                self?.presentNext(fromHidden: false)
            }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.queuePause, execute: work)
            return
        }
        if model.reading != nil {
            closeVoxOnly()
        }
        dismiss()
    }

    /// Con la permanenza disattivata, un trascinamento aggiunge 5 s alla scomparsa.
    private func extendHideAfterDrag() {
        guard !permanence, model.phase == .idle else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let remaining = max(0, (hideDeadline ?? now) - now)
        scheduleHide(after: remaining + Self.dragGrace)
    }

    private func refreshChrome() {
        if showingGreeting {
            model.remaining = 0
            model.previous = 0
            syncCornerButtons()
            return
        }
        let remaining = max(0, queue.count - 1)
        let previous = history.count
        model.remaining = remaining
        model.previous = previous
        let nextLabel = remaining <= 1 ? "VOX successiva" : "\(remaining) VOX successive"
        nextButton.toolTip = nextLabel
        nextButton.setAccessibilityLabel(nextLabel)
        let backLabel = previous <= 1 ? "VOX precedente" : "\(previous) VOX precedenti"
        backButton.toolTip = backLabel
        backButton.setAccessibilityLabel(backLabel)
        syncCornerButtons()
    }

    /// Restituisce `true` se il globo stava entrando in scena.
    @discardableResult
    private func show() -> Bool {
        let entering = model.phase == .hidden || model.phase == .leaving
        if entering {
            reposition()
            panel.orderFrontRegardless()
            model.enter()
        }
        return entering
    }

    private func dismiss() {
        history.removeAll()
        model.leave { [weak self] in
            self?.panel.orderOut(nil)
            self?.movedThisAppearance = false
        }
    }

    private func drag(with event: NSEvent) {
        movedThisAppearance = true
        var origin = panel.frame.origin
        origin.x += event.deltaX
        origin.y -= event.deltaY
        panel.setFrameOrigin(origin)
    }

    /// Angolo inferiore destro dell'area visibile dello schermo su cui si trova il puntatore.
    private func reposition() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = CGPoint(x: visible.maxX - Self.size.width - Self.margin,
                             y: visible.minY + Self.margin)
        panel.setFrameOrigin(origin)
        syncCornerButtons()
    }

    private func repositionIfNeeded() {
        guard !movedThisAppearance, model.phase != .hidden else { return }
        reposition()
    }

    private func globeRect() -> CGRect {
        let inset = (Self.globeArea.width - Self.globeDrawn) / 2
        return CGRect(
            x: Self.size.width - Self.globeArea.width + inset,
            y: inset,
            width: Self.globeDrawn,
            height: Self.globeDrawn
        )
    }

    private func cardRect() -> CGRect? {
        guard let reading = model.reading else { return nil }
        return CGRect(
            x: Self.size.width - Self.cardTrailing - VoxLayout.width,
            y: Self.globeArea.height + Self.cardGap,
            width: VoxLayout.width,
            height: reading.height
        )
    }

    private func isInteractive(at point: CGPoint) -> Bool {
        if globeRect().insetBy(dx: -4, dy: -4).contains(point) { return true }
        if let card = cardRect(), card.contains(point) { return true }
        return false
    }

    /// Bersagli di clic allineati a X, successiva (basso a destra) e precedente (basso a sinistra).
    private func syncCornerButtons() {
        guard let reading = model.reading else {
            closeButton.isHidden = true
            nextButton.isHidden = true
            backButton.isHidden = true
            updateIgnoresMouseEvents()
            return
        }
        let size = VoxCornerButton.size
        let outset = VoxCornerButton.outset
        let cardRight = Self.size.width - Self.cardTrailing
        let cardLeft = cardRight - VoxLayout.width
        let cardBottom = Self.globeArea.height + Self.cardGap
        let cardTop = cardBottom + reading.height
        closeButton.frame = CGRect(
            x: cardRight - size + outset,
            y: cardTop - size + outset,
            width: size,
            height: size
        )
        closeButton.isHidden = false
        nextButton.frame = CGRect(
            x: cardRight - size + outset,
            y: cardBottom - outset,
            width: size,
            height: size
        )
        nextButton.isHidden = model.remaining == 0
        backButton.frame = CGRect(
            x: cardLeft - outset,
            y: cardBottom - outset,
            width: size,
            height: size
        )
        backButton.isHidden = model.previous == 0
        updateIgnoresMouseEvents()
    }

    /// Con il click-through la finestra ignora i clic, tranne globo, fumetto e i tre dischi.
    private func updateIgnoresMouseEvents() {
        guard clickThrough else {
            panel.ignoresMouseEvents = false
            return
        }
        let mouse = NSEvent.mouseLocation
        if isHot(closeButton, mouse: mouse) || isHot(nextButton, mouse: mouse) || isHot(backButton, mouse: mouse) {
            panel.ignoresMouseEvents = false
            return
        }
        let local = panel.convertPoint(fromScreen: mouse)
        panel.ignoresMouseEvents = !isInteractive(at: local)
    }

    private func isHot(_ button: VoxCornerButton, mouse: NSPoint) -> Bool {
        !button.isHidden && button.screenFrame.insetBy(dx: -4, dy: -4).contains(mouse)
    }

    private func playSoundIfAllowed() {
        guard soundEnabled else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        NSSound(named: "Tink")?.play()
    }

    private func startMouseTracking() {
        let update: (NSEvent) -> Void = { [weak self] _ in
            DispatchQueue.main.async { self?.updateIgnoresMouseEvents() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: update) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: {
            update($0)
            return $0
        }) {
            mouseMonitors.append(local)
        }
    }
}

/// Clic e trascinamento su globo e fumetto. Fuori da quei rettangoli non intercetta nulla.
final class MascotHitView: NSView {
    var isInteractive: (CGPoint) -> Bool = { _ in false }
    var onClick: () -> Void = {}
    var onDrag: (NSEvent) -> Void = { _ in }
    var onDragEnd: () -> Void = {}

    private var down: NSPoint?
    private var dragged = false

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        down = convert(event.locationInWindow, from: nil)
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down else { return }
        let now = convert(event.locationInWindow, from: nil)
        if !dragged, hypot(now.x - down.x, now.y - down.y) > 4 {
            dragged = true
            onDrag(event)
        } else if dragged {
            onDrag(event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragged {
            onDragEnd()
        } else {
            onClick()
        }
        down = nil
        dragged = false
    }
}
