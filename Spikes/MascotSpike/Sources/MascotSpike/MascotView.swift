import AppKit
import simd
import SwiftUI

@MainActor
final class MascotModel: ObservableObject {
    enum Phase { case hidden, entering, idle, leaving }

    @Published private(set) var phase: Phase = .hidden
    @Published var surface: Surface = .dark
    /// VOX mostrata sopra il globo; `nil` quando il fumetto è nascosto.
    @Published private(set) var reading: VoxLayout?
    private(set) var typingStart: TimeInterval = 0
    /// Dopo aver scritto la VOX il globo guarda chi osserva, poi torna al puntatore.
    static let lookAtViewer: TimeInterval = 1.2
    /// Vero solo mentre qualcosa si muove: sguardo che insegue il puntatore, battito di ciglia.
    /// Da fermo il render loop è in pausa, anche con Globy sempre presente.
    @Published private(set) var animating = false
    /// Cornice della finestra in coordinate schermo, per orientare lo sguardo.
    var windowFrame: () -> CGRect = { .zero }
    let gaze = GazeTracker()
    private(set) var blinkStart: TimeInterval = -.infinity
    private(set) var doubleBlink = false

    private var generation = 0
    private var activeUntil: TimeInterval = 0
    private var sleepWork: DispatchWorkItem?
    private var blinkTimer: Timer?
    private var blinkCount = 0
    private var mouseMonitors: [Any] = []

    func enter() {
        generation += 1
        let current = generation
        phase = .entering
        startLife()
        wake(for: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.generation == current else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { self.phase = .idle }
        }
    }

    /// Prima il globo, poi il fumetto; poi il testo si scrive e gli occhi lo seguono.
    /// Restituisce dopo quanti secondi lettura e sguardo verso chi osserva sono finiti.
    @discardableResult
    func present(_ vox: Vox) -> TimeInterval {
        let current = generation
        let layout = VoxLayout(vox)
        let delay = phase == .idle ? 0.1 : 0.7
        let pop = 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == current, self.phase != .hidden else { return }
            self.typingStart = Date.timeIntervalSinceReferenceDate + pop
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { self.reading = layout }
            self.wake(for: pop + layout.typingDuration + Self.lookAtViewer + 0.8)
        }
        return delay + pop + layout.typingDuration + Self.lookAtViewer
    }

    func dismissVox() {
        withAnimation(.easeOut(duration: 0.3)) { reading = nil }
    }

    enum GazeTarget { case cursor, viewer, point(CGPoint) }

    /// Dove guarda il globo all'istante `t`: il carattere che si sta scrivendo, poi chi
    /// osserva, poi il puntatore.
    func gazeTarget(at t: TimeInterval) -> GazeTarget {
        guard let reading else { return .cursor }
        let typingEnd = typingStart + reading.typingDuration
        if t < typingEnd {
            return .point(caretOnScreen(reading, count: reading.typedCount(elapsed: t - typingStart)))
        }
        return t < typingEnd + Self.lookAtViewer ? .viewer : .cursor
    }

    var globeCenter: CGPoint {
        let f = windowFrame()
        return CGPoint(x: f.maxX - MascotWindowController.globeArea.width / 2,
                       y: f.minY + MascotWindowController.globeArea.height / 2)
    }

    /// Stessa geometria di `MascotView`: fumetto allineato a destra, sopra il globo.
    private func caretOnScreen(_ layout: VoxLayout, count: Int) -> CGPoint {
        let f = windowFrame()
        let caret = layout.caret(after: count)
        let cardMinX = f.maxX - MascotWindowController.cardTrailing - VoxLayout.width
        let cardTop = f.minY + MascotWindowController.globeArea.height + MascotWindowController.cardGap + layout.height
        return CGPoint(x: cardMinX + VoxLayout.padding + caret.x,
                       y: cardTop - VoxLayout.padding - VoxLayout.headerHeight - VoxLayout.spacing - caret.y)
    }

    func leave(completion: @escaping () -> Void) {
        generation += 1
        let current = generation
        withAnimation(.easeIn(duration: 0.35)) {
            phase = .leaving
            reading = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.generation == current else { return }
            self.phase = .hidden
            self.stopLife()
            completion()
        }
    }

    /// Reazione a una nuova VOX quando il globo è già a schermo: doppio battito.
    func greet() {
        blink(double: true)
    }

    private func startLife() {
        guard blinkTimer == nil else { return }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.blinkCount += 1
                self.blink(double: self.blinkCount % 3 == 0)
            }
        }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.wake(for: 0.8) }
        }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { handler($0); return $0 }) {
            mouseMonitors.append(local)
        }
    }

    private func stopLife() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
        sleepWork?.cancel()
        animating = false
    }

    private func blink(double: Bool) {
        blinkStart = Date.timeIntervalSinceReferenceDate
        doubleBlink = double
        wake(for: double ? 0.5 : 0.25)
    }

    /// Tiene acceso il render loop almeno per `duration` secondi.
    private func wake(for duration: TimeInterval) {
        let now = Date.timeIntervalSinceReferenceDate
        guard now + duration > activeUntil else { return }
        activeUntil = now + duration
        if !animating { animating = true }
        guard sleepWork == nil else { return }
        scheduleSleep(after: duration)
    }

    private func scheduleSleep(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.sleepWork = nil
            let remaining = self.activeUntil - Date.timeIntervalSinceReferenceDate
            if remaining > 0.01 {
                self.sleepWork = nil
                self.scheduleSleep(after: remaining)
            } else {
                self.animating = false
            }
        }
        sleepWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

/// Sguardo smorzato: segue il bersaglio senza scatti.
@MainActor
final class GazeTracker {
    private var value = CGVector.zero
    private var last: TimeInterval?

    func update(at t: TimeInterval, center: CGPoint, target: MascotModel.GazeTarget) -> CGVector {
        let goal: CGVector
        switch target {
        case .viewer:
            goal = .zero
        case .cursor:
            goal = Self.direction(to: NSEvent.mouseLocation, from: center, falloff: 500, reach: 0.45)
        case .point(let p):
            // Il testo è vicino: più sensibile, così la lettura si vede.
            goal = Self.direction(to: p, from: center, falloff: 260, reach: 0.5)
        }
        let dt = min(t - (last ?? t), 0.1)
        last = t
        let k = min(1, dt * 9)
        value.dx += (goal.dx - value.dx) * k
        value.dy += (goal.dy - value.dy) * k
        return value
    }

    private static func direction(to p: CGPoint, from center: CGPoint, falloff: Double, reach: Double) -> CGVector {
        let dx = p.x - center.x, dy = p.y - center.y
        let dist = max(hypot(dx, dy), 1)
        let amount = min(dist / falloff, 1) * reach
        return CGVector(dx: dx / dist * amount, dy: dy / dist * amount * 0.7)
    }
}

struct MascotView: View {
    @ObservedObject var model: MascotModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visible: Bool { model.phase == .idle }

    var body: some View {
        VStack(alignment: .trailing, spacing: MascotWindowController.cardGap) {
            if let reading = model.reading {
                VoxCard(layout: reading, typingStart: model.typingStart, animating: model.animating, surface: model.surface)
                    .padding(.trailing, MascotWindowController.cardTrailing)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
            }
            globe
        }
        .frame(width: MascotWindowController.size.width, height: MascotWindowController.size.height,
               alignment: .bottomTrailing)
    }

    private var globe: some View {
        ZStack {
            if model.surface.isGlass {
                GlobeGlass(surface: model.surface)
            }
            GlobeBody(surface: model.surface)
            // Il render loop gira solo mentre qualcosa si muove e il movimento è ammesso,
            // e ridisegna soltanto griglia e occhi: corpo e riflesso sono statici.
            TimelineView(.animation(paused: !model.animating || reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GlobeFeatures(glass: model.surface.isGlass,
                              gaze: reduceMotion ? .zero : model.gaze.update(at: t, center: model.globeCenter, target: model.gazeTarget(at: t)),
                              eyeOpen: reduceMotion ? 1 : Self.eyeOpen(t - model.blinkStart, double: model.doubleBlink))
            }
            GlobeSheen()
        }
        .frame(width: 116, height: 116)
        .frame(width: MascotWindowController.globeArea.width, height: MascotWindowController.globeArea.height)
        .opacity(visible ? 1 : 0)
        .scaleEffect(reduceMotion || visible ? 1 : 0.7, anchor: .bottom)
        .offset(y: reduceMotion || visible ? 0 : 40)
        .accessibilityLabel("Globy")
    }

    /// Apertura degli occhi `elapsed` secondi dopo l'inizio di un battito.
    static func eyeOpen(_ elapsed: Double, double: Bool) -> Double {
        func blink(at start: Double) -> Double {
            let d = elapsed - start
            guard d >= 0, d < 0.18 else { return 1 }
            return abs(d - 0.09) / 0.09
        }
        return min(blink(at: 0), double ? blink(at: 0.28) : 1)
    }
}

/// Geometria condivisa dai tre strati del globo.
enum Globe {
    /// Inclinazione dell'asse verso chi guarda: rende le latitudini ellissi.
    static let tilt = 0.32
    /// Occhi in posizione fissa sulla sfera: guardano chi osserva quando la testa è dritta.
    static let eyeLon = 0.38, eyeLat = 0.08 + tilt
    static let parallels: [Double] = [-35, 0, 35]
    static let meridians: [Double] = [30, 90, 150]

    static func radius(_ size: CGSize) -> Double { min(size.width, size.height) / 2 * 0.86 }
    static func center(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2 - radius(size) * 0.04)
    }
    static func disk(_ size: CGSize) -> Path {
        let r = radius(size), c = center(size)
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// Punto della sfera → schermo. La testa ruota di `gaze.dx` (destra/sinistra) e
    /// `gaze.dy` (su/giù) come un corpo rigido: griglia e occhi si muovono insieme.
    /// Restituisce anche la profondità.
    static func project(lon: Double, lat: Double, gaze: CGVector, center c: CGPoint, radius r: Double) -> (CGPoint, Double) {
        let v = rotate(point(lon: lon, lat: lat), gaze: gaze)
        return (screen(v, center: c, radius: r), v.z)
    }

    /// Punto unitario della sfera nelle coordinate del corpo (z verso chi guarda).
    static func point(lon: Double, lat: Double) -> SIMD3<Double> {
        SIMD3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
    }

    /// Corpo → vista: rotazione della testa attorno all'asse verticale, poi inclinazione.
    static func rotate(_ v: SIMD3<Double>, gaze: CGVector) -> SIMD3<Double> {
        let yaw = gaze.dx, pitch = tilt - gaze.dy
        let x = v.x * cos(yaw) + v.z * sin(yaw)
        let z = -v.x * sin(yaw) + v.z * cos(yaw)
        return SIMD3(x, v.y * cos(pitch) - z * sin(pitch), v.y * sin(pitch) + z * cos(pitch))
    }

    static func screen(_ v: SIMD3<Double>, center c: CGPoint, radius r: Double) -> CGPoint {
        CGPoint(x: c.x + v.x * r, y: c.y - v.y * r)
    }
}

/// Materiale della sfera, da confrontare dal vivo: il vetro dipende da ciò che c'è dietro.
enum Surface: String, CaseIterable {
    case dark, liquidGlass, clearGlass, frosted

    var title: String {
        switch self {
        case .dark: "Scura"
        case .liquidGlass: "Liquid Glass"
        case .clearGlass: "Liquid Glass trasparente"
        case .frosted: "Vetro smerigliato"
        }
    }

    var isGlass: Bool { self != .dark }
}

/// Ombra e corpo della sfera, con luce dall'alto a sinistra. Sul vetro il corpo diventa
/// una velatura leggera: volume e bordo di Fresnel.
struct GlobeBody: View {
    var surface: Surface = .dark

    var body: some View {
        Canvas { ctx, size in
            let r = Globe.radius(size), c = Globe.center(size), disk = Globe.disk(size)
            let light = CGPoint(x: c.x - r * 0.45, y: c.y - r * 0.5)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: r * 0.08))
                l.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.7, y: c.y + r * 0.92, width: r * 1.4, height: r * 0.16)),
                       with: .color(.black.opacity(surface.isGlass ? 0.22 : 0.35)))
            }
            guard surface.isGlass else {
                ctx.fill(disk, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(white: 0.36), location: 0),
                        .init(color: Color(white: 0.14), location: 0.45),
                        .init(color: Color(white: 0.04), location: 1),
                    ]),
                    center: light, startRadius: 0, endRadius: r * 1.9))
                return
            }
            ctx.fill(disk, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.10), location: 0),
                    .init(color: .black.opacity(0.0), location: 0.5),
                    .init(color: .black.opacity(0.14), location: 1),
                ]),
                center: light, startRadius: 0, endRadius: r * 1.9))
            ctx.fill(disk, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0), location: 0.7),
                    .init(color: .white.opacity(0.18), location: 0.95),
                    .init(color: .white.opacity(0.05), location: 1),
                ]),
                center: c, startRadius: 0, endRadius: r))
        }
    }
}

/// Vetro di sistema dietro il disegno: sfoca e rifrange ciò che c'è sotto la finestra.
/// Liquid Glass richiede macOS 26; altrimenti si usa il vetro smerigliato.
struct GlobeGlass: View {
    var surface: Surface

    var body: some View {
        GeometryReader { geo in
            let r = Globe.radius(geo.size), c = Globe.center(geo.size)
            GlassPanelView(surface: surface, cornerRadius: r)
                .id(surface)
                .frame(width: 2 * r, height: 2 * r)
                .clipShape(Circle())
                .position(c)
        }
    }
}

/// Riflesso morbido e luce di contorno, sopra griglia e occhi.
struct GlobeSheen: View {
    var body: some View {
        Canvas { ctx, size in
            let r = Globe.radius(size), c = Globe.center(size), disk = Globe.disk(size)
            ctx.clip(to: disk)
            ctx.drawLayer { s in
                s.addFilter(.blur(radius: r * 0.12))
                s.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.78, width: r * 0.5, height: r * 0.34)),
                       with: .color(.white.opacity(0.22)))
            }
            ctx.stroke(disk, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.0), .white.opacity(0.14)]),
                startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)),
                lineWidth: r * 0.04)
        }
        .allowsHitTesting(false)
    }
}

/// Unico strato animato: poche linee di latitudine e longitudine e occhi a trattino.
struct GlobeFeatures: View {
    var glass = false
    var gaze: CGVector
    var eyeOpen: Double

    var body: some View {
        Canvas { ctx, size in
            let r = Globe.radius(size), c = Globe.center(size)
            Self.drawGrid(in: &ctx, glass: glass, gaze: gaze, center: c, radius: r)
            Self.drawEyes(in: &ctx, glass: glass, gaze: gaze, open: eyeOpen, center: c, radius: r)
        }
    }

    /// Paralleli e meridiani come tubicini in rilievo. Ogni tubicino è un nastro costruito
    /// sulla superficie 3D e poi proiettato, come gli occhi: si assottiglia da solo dove
    /// la prospettiva lo schiaccia e scompare dietro il bordo senza tagli netti.
    /// Tre nastri sovrapposti danno la sezione rotonda: bordo, corpo e riflesso spostato
    /// verso la luce (in alto a sinistra). Sopra, l'ombreggiatura della sfera.
    private static func drawGrid(in ctx: inout GraphicsContext, glass: Bool, gaze: CGVector, center c: CGPoint, radius r: Double) {
        let steps = 120
        // Semilarghezza angolare: al centro il tubicino è largo circa 0,062 r,
        // cioè 1/4 della larghezza degli occhi.
        let hw = 0.031
        let light = SIMD2<Double>(-0.6, -0.8)
        var edge = Path(), core = Path(), shine = Path()

        func addRibbon(_ path: inout Path, _ left: [CGPoint], _ right: [CGPoint]) {
            guard left.count > 1 else { return }
            path.move(to: left[0])
            left.dropFirst().forEach { path.addLine(to: $0) }
            right.reversed().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }

        func addCurve(_ point: (Double) -> SIMD3<Double>) {
            let pts = (0..<steps).map { point(Double($0) / Double(steps)) }
            // Si parte da un punto nascosto, così un tratto visibile non si spezza a metà.
            let start = pts.indices.first { Globe.rotate(pts[$0], gaze: gaze).z < -0.05 } ?? 0
            var el: [CGPoint] = [], er: [CGPoint] = [], cl: [CGPoint] = [], cr: [CGPoint] = []
            var sl: [CGPoint] = [], sr: [CGPoint] = []
            func flush() {
                addRibbon(&edge, el, er); addRibbon(&core, cl, cr); addRibbon(&shine, sl, sr)
                el = []; er = []; cl = []; cr = []; sl = []; sr = []
            }
            for j in 0...steps {
                let i = (start + j) % steps
                let p = pts[i]
                // Leggermente oltre l'orizzonte: il bordo della sfera fa da maschera.
                guard Globe.rotate(p, gaze: gaze).z > -0.05 else { flush(); continue }
                let tangent = pts[(i + 1) % steps] - pts[(i + steps - 1) % steps]
                let side = simd_normalize(simd_cross(tangent, p))
                let s3 = Globe.rotate(side, gaze: gaze)
                let s2 = SIMD2(s3.x, -s3.y)
                let len = simd_length(s2)
                let k = len > 1e-3 ? simd_clamp(simd_dot(s2 / len, light), -1, 1) : 0
                func at(_ offset: Double) -> CGPoint {
                    Globe.screen(Globe.rotate(simd_normalize(p + side * offset), gaze: gaze), center: c, radius: r)
                }
                el.append(at(hw)); er.append(at(-hw))
                cl.append(at(hw * (0.12 * k + 0.72))); cr.append(at(hw * (0.12 * k - 0.72)))
                sl.append(at(hw * (0.45 * k + 0.14))); sr.append(at(hw * (0.45 * k - 0.14)))
            }
            flush()
        }
        for lat in Globe.parallels {
            addCurve { Globe.point(lon: $0 * 2 * .pi, lat: lat * .pi / 180) }
        }
        for lon in Globe.meridians {
            addCurve { Globe.point(lon: lon * .pi / 180, lat: ($0 - 0.5) * 2 * .pi) }
        }

        let disk = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        ctx.drawLayer { l in
            l.clip(to: disk)
            l.fill(edge, with: .color(Color(white: glass ? 0.62 : 0.16)))
            l.fill(core, with: .color(Color(white: glass ? 0.85 : 0.30)))
            l.drawLayer { hi in
                hi.addFilter(.blur(radius: r * 0.006))
                hi.fill(shine, with: .color(Color(white: glass ? 1 : 0.62)))
            }
            // Stessa luce della sfera: i tubicini si scuriscono lontano dalla luce.
            l.blendMode = .sourceAtop
            l.fill(disk, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(glass ? 0.1 : 0.25), location: 0.55),
                    .init(color: .black.opacity(glass ? 0.35 : 0.7), location: 1),
                ]),
                center: CGPoint(x: c.x - r * 0.45, y: c.y - r * 0.5), startRadius: 0, endRadius: r * 1.9))
        }
    }

    /// Occhi solidali alla sfera, disegnati come capsule sulla superficie: seguono la
    /// curvatura e si deformano in prospettiva quando la testa gira.
    private static func drawEyes(in ctx: inout GraphicsContext, glass: Bool, gaze: CGVector, open: Double,
                                 center c: CGPoint, radius r: Double) {
        // Angoli sulla sfera, in radianti: semilarghezza e metà del tratto rettilineo.
        let halfWidth = 0.115
        let halfStraight = 0.19
        // Il battito schiaccia la capsula in verticale fino a una sottile fessura.
        let squash = max(open, 0.12)
        let arcSteps = 10, sideSteps = 8
        var eyes = Path()
        for side in [-1.0, 1.0] {
            // Contorno della capsula nel piano locale (u verso destra, v verso l'alto).
            var outline: [(u: Double, v: Double)] = []
            for k in 0...arcSteps {       // estremità superiore
                let a = Double.pi * Double(k) / Double(arcSteps)
                outline.append((halfWidth * cos(a), halfStraight + halfWidth * sin(a)))
            }
            for k in 0...sideSteps {      // lato sinistro, dall'alto in basso
                outline.append((-halfWidth, halfStraight - 2 * halfStraight * Double(k) / Double(sideSteps)))
            }
            for k in 0...arcSteps {       // estremità inferiore
                let a = Double.pi + Double.pi * Double(k) / Double(arcSteps)
                outline.append((halfWidth * cos(a), -halfStraight + halfWidth * sin(a)))
            }
            for k in 0...sideSteps {      // lato destro, dal basso in alto
                outline.append((halfWidth, -halfStraight + 2 * halfStraight * Double(k) / Double(sideSteps)))
            }
            for (n, p) in outline.enumerated() {
                let lat = Globe.eyeLat + p.v * squash
                let lon = side * Globe.eyeLon + p.u / cos(lat)
                let pt = Globe.project(lon: lon, lat: lat, gaze: gaze, center: c, radius: r).0
                n == 0 ? eyes.move(to: pt) : eyes.addLine(to: pt)
            }
            eyes.closeSubpath()
        }
        if glass {
            // Alone scuro morbido: gli occhi restano leggibili anche su sfondi chiari.
            ctx.drawLayer { halo in
                halo.addFilter(.blur(radius: r * 0.12))
                halo.fill(eyes, with: .color(.black.opacity(0.35)))
            }
        }
        ctx.drawLayer { glow in
            glow.addFilter(.blur(radius: r * 0.13))
            glow.fill(eyes, with: .color(.white.opacity(0.55)))
        }
        ctx.fill(eyes, with: .color(.white))
    }
}

/// Globo completo, usato per `--snapshot`. Il vetro di sistema non compare nelle
/// esportazioni: qui si vedono solo le velature disegnate sopra.
struct GlobeCanvas: View {
    var surface: Surface = .dark
    var gaze: CGVector
    var eyeOpen: Double

    var body: some View {
        ZStack {
            GlobeBody(surface: surface)
            GlobeFeatures(glass: surface.isGlass, gaze: gaze, eyeOpen: eyeOpen)
            GlobeSheen()
        }
    }
}

/// Card a metà scrittura, con un punto rosso dove gli occhi guardano: verifica che la
/// posizione calcolata con TextKit coincida con il testo disegnato da SwiftUI.
@MainActor
private var caretCheck: some View {
    let layout = VoxLayout(.sample)
    let n = 250
    let caret = layout.caret(after: n)
    return VoxCard(layout: layout, typingStart: Date.timeIntervalSinceReferenceDate - Double(n) / VoxLayout.charactersPerSecond,
                   animating: true, surface: .dark)
        .overlay(alignment: .topLeading) {
            Circle().fill(.red).frame(width: 6, height: 6)
                .offset(x: VoxLayout.padding + caret.x - 3,
                        y: VoxLayout.padding + VoxLayout.headerHeight + VoxLayout.spacing + caret.y - 3)
        }
}

/// Foglio di controllo per `--snapshot`: superficie scura su sfondo chiaro e scuro, e
/// velature del vetro su uno sfondo colorato.
struct SnapshotSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            row(.dark).background(Color(white: 0.93))
            row(.dark).background(Color(white: 0.12))
            row(.liquidGlass).background(LinearGradient(colors: [.orange, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(alignment: .bottom, spacing: 0) {
                caretCheck
                GlobeCanvas(gaze: CGVector(dx: -0.35, dy: 0.05), eyeOpen: 1).frame(width: 150, height: 150)
            }
            .padding(20)
            .frame(width: 540)
            .background(Color(white: 0.75))
        }
    }

    private func row(_ surface: Surface) -> some View {
        HStack(spacing: 0) {
            GlobeCanvas(surface: surface, gaze: .zero, eyeOpen: 1)
            GlobeCanvas(surface: surface, gaze: CGVector(dx: 0.45, dy: -0.25), eyeOpen: 1)
            GlobeCanvas(surface: surface, gaze: CGVector(dx: -0.4, dy: 0.3), eyeOpen: 0)
        }
        .frame(width: 540, height: 180)
    }
}
