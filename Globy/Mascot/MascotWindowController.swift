import AppKit
import GlobyCore
import SwiftUI

/// Finestra trasparente, non attivante, presente su tutti gli Space e sopra il fullscreen.
@MainActor
final class MascotWindowController {
    static var globeArea: CGSize { MascotLayout.globeArea }
    static var globeDrawn: CGFloat { MascotLayout.globeDrawn }
    static let margin = MascotLayout.margin
    /// Quanto resta una domanda «Sì / No» dopo la lettura, se nessuno risponde.
    static let choiceLinger: TimeInterval = 20
    static let queuePause: TimeInterval = 1
    static let dragGrace: TimeInterval = 5

    private let panel: NSPanel
    private let model = MascotModel()
    private let closeButton = VoxCornerButton(frame: .zero, tooltip: "Chiudi", accessibilityLabel: "Chiudi")
    private let nextButton = VoxCornerButton(frame: .zero, tooltip: "VOX successivo", accessibilityLabel: "VOX successivo")
    private let backButton = VoxCornerButton(frame: .zero, tooltip: "VOX precedente", accessibilityLabel: "VOX precedente")
    private let yesButton = VoxCornerButton(frame: .zero, tooltip: "Sì, partiamo", accessibilityLabel: "Sì, partiamo")
    private let noButton = VoxCornerButton(frame: .zero, tooltip: "No, grazie", accessibilityLabel: "No, grazie")
    private let hitView = MascotHitView(frame: .zero)
    private var hideWork: DispatchWorkItem?
    private var hideDeadline: TimeInterval?
    private var mouseMonitors: [Any] = []
    private var queue: [Vox] = []
    /// VOX già mostrati in questa sessione, per la freccia indietro.
    private var history: [Vox] = []
    private var current: Vox?
    /// Fumetto di saluto: non è in coda e non è un VOX.
    private var showingGreeting = false
    /// VOX portati dal saluto di rientro: se il saluto viene ignorato escono dalla coda,
    /// quelli arrivati nel frattempo restano.
    private var greetingItems: [Vox] = []
    /// Il saluto chiede «Sì / No» invece di offrire la freccia.
    private var greetingAsksChoice = false
    /// Fumetti che seguono questo saluto (onboarding): il numerino sulla freccia.
    private var greetingSteps = 0
    private var greetingCompletion: ((GreetingOutcome) -> Void)?

    enum GreetingOutcome { case accepted, declined, timedOut }
    /// Anteprima delle dimensioni, finché le Impostazioni sono aperte.
    private var previewing = false
    /// Le Impostazioni sono aperte: finito un saluto o un VOX, l'anteprima torna.
    private var previewRequested = false
    private var movedThisAppearance = false
    /// Centro del disco disegnato, in coordinate schermo. Resta fisso mentre la finestra si adatta al fumetto.
    private var globeCenterScreen: CGPoint?
    /// Altezza del fumetto da tenere nella finestra anche mentre compare o scompare.
    private var layoutCardHeight: CGFloat?

    var surface: Surface {
        get { model.surface }
        set { model.surface = newValue }
    }

    var soundEnabled = true

    var gazeFollowsPointer: Bool {
        get { model.followsPointer }
        set { model.followsPointer = newValue }
    }

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
                scheduleHide(after: ReadingPolicy.linger(forText: VoxLayout.fitted(current?.text ?? "")))
            }
        }
    }

    var clickThrough = true {
        didSet { updateIgnoresMouseEvents() }
    }

    init() {
        panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.globeArea),
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

        let root = NSView(frame: CGRect(origin: .zero, size: Self.globeArea))
        let host = NSHostingView(rootView: MascotView(model: model))
        host.frame = root.bounds
        host.autoresizingMask = [.width, .height]
        hitView.autoresizingMask = [.width, .height]
        hitView.frame = root.bounds
        hitView.onClick = { [weak self] in self?.openCurrent() }
        hitView.contextMenu = { [weak self] in self?.makeContextMenu() }
        hitView.onDrag = { [weak self] event in self?.drag(with: event) }
        hitView.onDragEnd = { [weak self] in self?.extendHideAfterDrag() }
        hitView.isInteractive = { [weak self] point in self?.isInteractive(at: point) ?? false }
        closeButton.isHidden = true
        closeButton.action = { [weak self] in self?.closeVoxOnly() }
        nextButton.isHidden = true
        nextButton.action = { [weak self] in self?.goToNext() }
        backButton.isHidden = true
        backButton.action = { [weak self] in self?.goToPrevious() }
        yesButton.isHidden = true
        yesButton.action = { [weak self] in self?.acceptGreeting() }
        noButton.isHidden = true
        noButton.action = { [weak self] in self?.declineGreeting() }
        root.addSubview(host)
        root.addSubview(hitView)
        root.addSubview(closeButton)
        root.addSubview(nextButton)
        root.addSubview(backButton)
        root.addSubview(yesButton)
        root.addSubview(noButton)
        panel.contentView = root

        model.onUserDismiss = { [weak self] in self?.closeVoxOnly() }
        model.onCardChange = { [weak self] in self?.syncCornerButtons() }
        model.onReserveCardHeight = { [weak self] height in
            self?.layoutCardHeight = height
            self?.applyLayout()
        }

        startMouseTracking()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.repositionIfNeeded() }
        }
    }

    /// Sta leggendo un VOX, un saluto o ha una coda: un avviso che non è un VOX aspetta.
    var isBusy: Bool {
        current != nil || showingGreeting || !queue.isEmpty
    }

    /// Accoda un VOX. Se il globo è nascosto, parte il richiamo; se sta già leggendo,
    /// le successive aspettano con una pausa di un secondo tra una e l'altra.
    func summon(vox: Vox) {
        queue.append(vox)
        if current == nil, !showingGreeting {
            presentNext(fromHidden: true)
        } else {
            refreshChrome()
        }
    }

    /// VOX scelto dal menu: passa davanti alla coda e compare subito.
    /// Durante un saluto aspetta il suo turno, come ogni altro VOX.
    func showNow(_ vox: Vox) {
        queue.removeAll { $0 == vox }
        queue.insert(vox, at: 0)
        if showingGreeting {
            refreshChrome()
            return
        }
        presentNext(fromHidden: current == nil, playSound: false)
    }

    func summonBurst(_ items: [Vox]) {
        items.forEach(summon)
    }

    /// Saluto di carattere: occhi sorridenti, niente permalink. Se porta dei VOX, la freccia
    /// li apre; se nessuno la usa, il saluto se ne va e i VOX restano nel menu.
    /// Mostra il fumetto di anteprima, se il globo non sta già dicendo altro.
    func showPreview() {
        previewRequested = true
        guard current == nil, !showingGreeting, !previewing else { return }
        previewing = true
        cancelHide()
        if model.phase == .hidden || model.phase == .leaving {
            movedThisAppearance = false
            if !show() { model.greet() }
        }
        refreshChrome()
        model.present(.preview)
    }

    func hidePreview() {
        previewRequested = false
        guard previewing else { return }
        previewing = false
        model.dismissVox()
        refreshChrome()
        if !permanence { dismiss() }
    }

    /// Impostazioni di dimensione cambiate: fumetto e pulsanti si adattano subito.
    func metricsDidChange() {
        model.refreshLayout()
        if model.phase != .hidden { applyLayout() }
        syncCornerButtons()
    }

    func presentGreeting(_ greeting: Vox = .greeting, then items: [Vox] = [], followingSteps: Int = 0,
                         completion: ((GreetingOutcome) -> Void)? = nil) {
        guard current == nil else {
            summonBurst(items)
            return
        }
        previewing = false
        queue.append(contentsOf: items)
        greetingItems.append(contentsOf: items)
        greetingSteps = followingSteps
        greetingCompletion = completion
        greetingAsksChoice = greeting.asksChoice && (!items.isEmpty || completion != nil)
        yesButton.toolTip = greeting.yesTitle
        yesButton.setAccessibilityLabel(greeting.yesTitle)
        noButton.toolTip = greeting.noTitle
        noButton.setAccessibilityLabel(greeting.noTitle)
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
        let readingDone = model.present(greeting)
        if permanence {
            cancelHide()
        } else {
            // A una domanda si lascia più tempo per rispondere.
            // A una domanda, o a un passo dell'onboarding, si lascia più tempo.
            let waitsForUser = greetingAsksChoice || greetingSteps > 0
            scheduleHide(after: readingDone + (waitsForUser ? Self.choiceLinger : ReadingPolicy.linger(forText: VoxLayout.fitted(greeting.text))))
        }
    }

    /// Clic su globo o fumetto: apre il VOX visibile su Chronocol, senza cambiare coda.
    private func openCurrent() {
        if previewing { return }
        if showingGreeting {
            // Con «Sì / No» si risponde dai pulsanti, non con un clic qualsiasi sul fumetto.
            if !queue.isEmpty || greetingSteps > 0, !greetingAsksChoice { acceptGreeting() }
            return
        }
        guard let current else { return }
        onOpen(current)
    }

    /// X: chiude solo il fumetto. Il globo resta se c'è la permanenza.
    private func closeVoxOnly() {
        if previewing {
            hidePreview()
            return
        }
        if showingGreeting {
            // X sul saluto vuol dire «dopo»: i VOX portati restano nel menu.
            finishGreeting(.declined)
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

    private func dropGreetingItems() {
        let brought = greetingItems
        queue.removeAll { brought.contains($0) }
        greetingItems.removeAll()
    }

    private func endGreeting() {
        greetingItems.removeAll()
        greetingAsksChoice = false
        greetingSteps = 0
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

    /// Freccia in basso a destra: passa al VOX successivo in coda.
    /// «No»: chiude il fumetto e, senza permanenza, il globo esce poco dopo.
    private func declineGreeting() {
        closeVoxOnly()
        if !permanence, current == nil, !showingGreeting { scheduleHide(after: 1.2) }
    }

    /// «Sì» o freccia sul saluto: parte la coda che il saluto ha portato.
    private func acceptGreeting() {
        guard showingGreeting else { return }
        finishGreeting(.accepted)
    }

    /// Chiude il saluto e avvisa chi l'ha chiesto; `completion` può presentarne un altro.
    private func finishGreeting(_ outcome: GreetingOutcome) {
        let completion = greetingCompletion
        greetingCompletion = nil
        if outcome != .accepted { dropGreetingItems() }
        endGreeting()
        completion?(outcome)
        // Risposta data e niente altro da dire: il globo esce poco dopo.
        if outcome != .timedOut, !showingGreeting, current == nil, queue.isEmpty, !permanence {
            scheduleHide(after: 1.2)
        }
    }

    private func goToNext() {
        guard !previewing else { return }
        if showingGreeting {
            acceptGreeting()
            return
        }
        guard queue.count > 1, let shown = queue.first else { return }
        history.append(shown)
        queue.removeFirst()
        presentNext(fromHidden: false)
    }

    /// Freccia in basso a sinistra: torna al VOX precedente.
    private func goToPrevious() {
        guard !previewing else { return }
        guard let previous = history.popLast() else { return }
        queue.insert(previous, at: 0)
        presentNext(fromHidden: false, playSound: false)
    }

    private func presentNext(fromHidden: Bool, playSound: Bool = true) {
        previewing = false
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
        onShow(vox)
        if permanence {
            cancelHide()
        } else {
            scheduleHide(after: readingDone + ReadingPolicy.linger(forText: VoxLayout.fitted(vox.text)))
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
        if permanence || previewing { return }
        if showingGreeting {
            finishGreeting(.timedOut)
            if queue.isEmpty, !showingGreeting { dismiss() }
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
        if previewing {
            // Frecce finte con numerini, solo per far vedere la misura dei pulsanti.
            model.remaining = 2
            model.previous = 1
            syncCornerButtons()
            return
        }
        if showingGreeting {
            model.remaining = greetingAsksChoice ? 0 : (greetingItems.isEmpty ? greetingSteps : queue.count)
            model.previous = 0
            let label = queue.count == 1 ? "Mostra il VOX" : "Mostra i \(queue.count) VOX"
            nextButton.toolTip = label
            nextButton.setAccessibilityLabel(label)
            syncCornerButtons()
            return
        }
        let remaining = max(0, queue.count - 1)
        let previous = history.count
        model.remaining = remaining
        model.previous = previous
        let nextLabel = remaining <= 1 ? "VOX successivo" : "\(remaining) VOX successivi"
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
            layoutCardHeight = nil
            reposition()
            panel.orderFrontRegardless()
            model.enter()
        }
        return entering
    }

    func dismissAll() {
        dismiss()
    }

    /// Da impostare da chi possiede la finestra delle Impostazioni.
    var onOpenPreferences: () -> Void = {}
    /// Clic sul fumetto di un VOX: la sessione lo segna come letto e apre Chronocol.
    var onOpen: (Vox) -> Void = { NSWorkspace.shared.open($0.permalink) }
    /// Un VOX è comparso nel fumetto.
    var onShow: (Vox) -> Void = { _ in }

    /// Clic destro su Globy o sul fumetto.
    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let prefs = NSMenuItem(title: "Impostazioni…", action: #selector(ContextMenuTarget.fire(_:)), keyEquivalent: "")
        prefs.target = contextTarget
        prefs.representedObject = { [weak self] in self?.onOpenPreferences() } as () -> Void
        menu.addItem(prefs)
        let hide = NSMenuItem(title: "Nascondi Globy", action: #selector(ContextMenuTarget.fire(_:)), keyEquivalent: "")
        hide.target = contextTarget
        hide.representedObject = { [weak self] in self?.hideNow() } as () -> Void
        menu.addItem(hide)
        return menu
    }

    private let contextTarget = ContextMenuTarget()

    /// «Nascondi Globy»: esce subito con fumetto e coda. I VOX restano nel menu; Globy
    /// torna al prossimo arrivo.
    func hideNow() {
        cancelHide()
        previewing = false
        previewRequested = false
        greetingCompletion = nil
        greetingItems.removeAll()
        greetingAsksChoice = false
        greetingSteps = 0
        showingGreeting = false
        model.setSmiling(false)
        queue.removeAll()
        history.removeAll()
        current = nil
        model.dismissVox()
        refreshChrome()
        model.leave { [weak self] in
            self?.layoutCardHeight = nil
            self?.panel.orderOut(nil)
            self?.movedThisAppearance = false
        }
    }

    private func dismiss() {
        if previewRequested, !previewing, current == nil, !showingGreeting {
            showPreview()
            return
        }
        history.removeAll()
        model.leave { [weak self] in
            self?.layoutCardHeight = nil
            self?.panel.orderOut(nil)
            self?.movedThisAppearance = false
        }
    }

    private func drag(with event: NSEvent) {
        movedThisAppearance = true
        let current = globeCenterScreen ?? CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        globeCenterScreen = CGPoint(x: current.x + event.deltaX, y: current.y - event.deltaY)
        applyLayout()
    }

    /// Angolo inferiore destro dell'area visibile dello schermo su cui si trova il puntatore.
    private func reposition() {
        let visible = visibleFrame(containing: NSEvent.mouseLocation)
        guard visible.width > 0 else { return }
        globeCenterScreen = MascotLayout.defaultGlobeCenter(in: visible)
        applyLayout()
    }

    private func repositionIfNeeded() {
        guard model.phase != .hidden else { return }
        if movedThisAppearance {
            applyLayout()
        } else {
            reposition()
        }
    }

    private func visibleFrame(containing point: CGPoint) -> CGRect {
        let screens = NSScreen.screens
        if let screen = screens.first(where: { $0.frame.contains(point) }) { return screen.visibleFrame }
        if let screen = screens.first(where: { $0.visibleFrame.contains(point) }) { return screen.visibleFrame }
        return NSScreen.main?.visibleFrame ?? .zero
    }

    /// Ricalcola fumetto e finestra intorno al globo, senza farlo uscire dalla `visibleFrame`.
    private func applyLayout() {
        let seed = globeCenterScreen ?? NSEvent.mouseLocation
        let visible = visibleFrame(containing: seed)
        guard visible.width > 0, visible.height > 0 else { return }
        let requested = globeCenterScreen ?? MascotLayout.defaultGlobeCenter(in: visible)
        let result = MascotLayout.placement(globeCenter: requested, cardHeight: layoutCardHeight, visible: visible)
        globeCenterScreen = result.center
        panel.setFrame(result.window, display: true, animate: false)
        if let root = panel.contentView {
            root.setFrameSize(result.window.size)
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.placement = result.placement
        }
        syncCornerButtons()
    }

    private func globeRect() -> CGRect {
        let inset = (Self.globeArea.width - Self.globeDrawn) / 2
        return model.placement.globe.insetBy(dx: inset, dy: inset)
    }

    private func cardRect() -> CGRect? {
        model.placement.card
    }

    private func isInteractive(at point: CGPoint) -> Bool {
        if globeRect().insetBy(dx: -4, dy: -4).contains(point) { return true }
        if let card = cardRect(), card.contains(point) { return true }
        return false
    }

    /// Bersagli di clic allineati a X, successiva (basso a destra) e precedente (basso a sinistra).
    private func syncCornerButtons() {
        guard let reading = model.reading, let card = model.placement.card else {
            closeButton.isHidden = true
            nextButton.isHidden = true
            backButton.isHidden = true
            yesButton.isHidden = true
            noButton.isHidden = true
            updateIgnoresMouseEvents()
            return
        }
        let size = VoxCornerButton.size
        let outset = VoxCornerButton.outset
        let cardRight = card.maxX
        let cardLeft = card.minX
        let cardBottom = card.minY
        let cardTop = card.maxY
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
        if reading.asksChoice {
            let pad = VoxLayout.padding
            let bottom = cardBottom + VoxLayout.cornerClearance
            let height = VoxLayout.choiceHeight
            yesButton.frame = CGRect(x: cardRight - pad - VoxLayout.yesWidth, y: bottom,
                                     width: VoxLayout.yesWidth, height: height)
            noButton.frame = CGRect(x: yesButton.frame.minX - VoxLayout.choiceSpacing - VoxLayout.noWidth,
                                    y: bottom, width: VoxLayout.noWidth, height: height)
        }
        yesButton.isHidden = !reading.asksChoice
        noButton.isHidden = !reading.asksChoice
        updateIgnoresMouseEvents()
    }

    /// Con il click-through la finestra ignora i clic, tranne globo, fumetto e i tre dischi.
    private func updateIgnoresMouseEvents() {
        let ignores = shouldIgnoreMouseEvents()
        // Scrivere la proprietà parla con il window server: solo quando cambia davvero.
        if panel.ignoresMouseEvents != ignores { panel.ignoresMouseEvents = ignores }
        updateCursor()
    }

    private var showsPointingHand = false

    /// Manina su globo, fumetto e pulsanti. Il pannello non diventa mai finestra chiave,
    /// quindi i cursor rect di AppKit non bastano: il cursore si imposta a mano.
    private func updateCursor() {
        let mouse = NSEvent.mouseLocation
        let overButton = [closeButton, nextButton, backButton, yesButton, noButton].contains { isHot($0, mouse: mouse) }
        let hot = panel.isVisible && (overButton || isInteractive(at: panel.convertPoint(fromScreen: mouse)))
        if hot {
            NSCursor.pointingHand.set()
        } else if showsPointingHand {
            NSCursor.arrow.set()
        }
        showsPointingHand = hot
    }

    private func shouldIgnoreMouseEvents() -> Bool {
        guard clickThrough else { return false }
        let mouse = NSEvent.mouseLocation
        if [closeButton, nextButton, backButton, yesButton, noButton].contains(where: { isHot($0, mouse: mouse) }) {
            return false
        }
        return !isInteractive(at: panel.convertPoint(fromScreen: mouse))
    }

    private func isHot(_ button: VoxCornerButton, mouse: NSPoint) -> Bool {
        !button.isHidden && button.screenFrame.insetBy(dx: -4, dy: -4).contains(mouse)
    }

    private func playSoundIfAllowed() {
        guard soundEnabled else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        NSSound(named: "Tink")?.play()
    }

    private var mouseUpdatePending = false

    private func startMouseTracking() {
        // Molti movimenti arrivano nello stesso giro: un solo aggiornamento in coda.
        let update: (NSEvent) -> Void = { [weak self] _ in
            guard let self, !self.mouseUpdatePending else { return }
            self.mouseUpdatePending = true
            DispatchQueue.main.async { [weak self] in
                self?.mouseUpdatePending = false
                self?.updateIgnoresMouseEvents()
            }
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
final class ContextMenuTarget: NSObject {
    @objc func fire(_ sender: NSMenuItem) {
        (sender.representedObject as? () -> Void)?()
    }
}

final class MascotHitView: NSView {
    var isInteractive: (CGPoint) -> Bool = { _ in false }
    var contextMenu: () -> NSMenu? = { nil }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
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
