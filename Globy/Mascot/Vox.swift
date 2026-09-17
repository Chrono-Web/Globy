import AppKit
import SwiftUI

/// VOX di esempio per il richiamo manuale. Nello spike non c'è sincronizzazione:
/// il testo è una fixture scritta a mano. Il permalink apre Chronocol nel browser.
struct Vox: Equatable {
    enum Kind {
        case publication
        case greeting
        /// VOX già uscito, mostrato su richiesta al primo avvio: non è una novità.
        case recent
        /// Anteprima delle dimensioni mentre le Preferenze sono aperte.
        case preview
    }

    var text: String
    var permalink: URL
    var kind: Kind = .publication
    /// Il fumetto mostra «Sì» e «No» invece della freccia.
    var asksChoice = false
    var yesTitle = "Sì, partiamo"
    var noTitle = "No, grazie"

    /// Saluto di primo avvio: non è un VOX e non nasce dalla sincronizzazione.
    static let greeting = Vox(
        text: "Ciao, sono Globy! Ti porto i VOX di Chronocol: quando ne esce uno nuovo vengo un attimo qui, in basso a destra.",
        permalink: URL(string: "https://chronocol.com/it")!,
        kind: .greeting
    )

    /// Saluto di rientro, all'avvio o al risveglio: il testo viene da `WelcomePolicy`.
    static func welcome(_ text: String, asksChoice: Bool = false,
                        yesTitle: String = "Sì, partiamo", noTitle: String = "No, grazie") -> Vox {
        Vox(text: text, permalink: URL(string: "https://chronocol.com/it")!, kind: .greeting,
            asksChoice: asksChoice, yesTitle: yesTitle, noTitle: noTitle)
    }

    static let preview = Vox(
        text: "Così appare il fumetto con queste dimensioni. X e frecce mostrano la misura dei pulsanti.",
        permalink: URL(string: "https://chronocol.com/it")!,
        kind: .preview
    )

    static let sample = Vox(
        text: """
        ⚡️🇵🇸🏚️ A six‑storey building housing ten families collapsed in Gaza City due to structural damage caused by previous Israeli bombings, killing at least twelve people and leaving a dozen survivors rescued by rescuers.

        🔻 Palestinian Civil Protection reports that dozens of people remain trapped under the rubble, including about fifty children.

        🔻 Rescue operations are also severely hampered by the lack of heavy equipment to remove the rubble, due to the entry bans imposed by Israel since October 7.
        """,
        permalink: URL(string: "https://chronocol.com/it/vox/lf9v8nvbbuimue2xq8ffy1so")!
    )

    static let sampleShortA = Vox(
        text: "Primo VOX di coda (fixture). Se ce n'è un altro, in basso a destra compare la freccia.",
        permalink: URL(string: "https://chronocol.com/it")!
    )

    static let sampleShortB = Vox(
        text: "Terzo VOX di coda (fixture). La X chiude solo il fumetto; la freccia passa al successivo.",
        permalink: URL(string: "https://chronocol.com/it")!
    )

    static let burst = [sampleShortA, sample, sampleShortB]
}

nonisolated(unsafe) private var storageKey: UInt8 = 0

/// Impaginazione della card calcolata con TextKit: altezza fissa fin dall'inizio e
/// posizione del carattere appena scritto, che gli occhi seguono.
@MainActor
final class VoxLayout {
    nonisolated static var width: CGFloat { 330 * MascotMetrics.textScale }
    nonisolated static var padding: CGFloat { 14 * MascotMetrics.textScale }
    /// Spazio dal bordo che nessun contenuto del fumetto può occupare vicino agli angoli:
    /// lì stanno X e frecce, disegnati a cavallo del bordo (`VoxCornerButton`).
    /// Regola generale: testo e pulsanti restano sempre fuori da queste zone.
    nonisolated static var cornerClearance: CGFloat { VoxCornerButton.size - VoxCornerButton.outset + 8 }
    nonisolated static var headerHeight: CGFloat { 14 * MascotMetrics.textScale }
    nonisolated static var spacing: CGFloat { 8 * MascotMetrics.textScale }
    nonisolated static var fontSize: CGFloat { 12.5 * MascotMetrics.textScale }
    static let charactersPerSecond = 80.0

    nonisolated static var choiceHeight: CGFloat { 24 * MascotMetrics.textScale }
    nonisolated static var choiceSpacing: CGFloat { 8 * MascotMetrics.textScale }
    nonisolated static var yesWidth: CGFloat { 92 * MascotMetrics.textScale }
    nonisolated static var noWidth: CGFloat { 78 * MascotMetrics.textScale }

    let vox: Vox
    let kind: Vox.Kind
    let asksChoice: Bool
    let text: String
    let count: Int
    let textHeight: CGFloat
    /// Fine di ogni carattere, calcolata una volta sola: `carets[n]` segue l'n-esimo.
    private let carets: [CGPoint]

    /// Limite di sicurezza: senza fonti un VOX sta quasi sempre sotto. Oltre, «…» e il
    /// resto è su Chronocol.
    static let maxLines = 16

    init(_ vox: Vox) {
        self.vox = vox
        kind = vox.kind
        asksChoice = vox.asksChoice
        let fitted = Self.fitted(vox.text)
        text = fitted
        count = fitted.count
        let (layoutManager, container, font) = Self.layout(fitted)
        // Un filo di margine: a corpi grandi SwiftUI misura le righe poco più alte di TextKit,
        // e senza margine l'ultima riga verrebbe troncata con i puntini.
        textHeight = ceil(layoutManager.usedRect(for: container).height + 2 * MascotMetrics.textScale)

        var carets = [CGPoint(x: 0, y: layoutManager.defaultLineHeight(for: font) / 2)]
        var index = fitted.startIndex
        while index < fitted.endIndex {
            let next = fitted.index(after: index)
            let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(index..<next, in: fitted), actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
            carets.append(CGPoint(x: rect.maxX, y: rect.midY))
            index = next
        }
        self.carets = carets
    }

    private static func layout(_ string: String) -> (NSLayoutManager, NSTextContainer, NSFont) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let storage = NSTextStorage(string: string, attributes: [.font: font])
        let container = NSTextContainer(size: CGSize(width: width - 2 * padding, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        // Lo storage deve vivere quanto il layout manager, che lo tiene solo debolmente.
        objc_setAssociatedObject(layoutManager, &storageKey, storage, .OBJC_ASSOCIATION_RETAIN)
        return (layoutManager, container, font)
    }

    /// Testo tagliato a `maxLines` righe con «…», alla larghezza e al corpo attuali.
    static func fitted(_ string: String) -> String {
        let (layoutManager, _, _) = layout(string)
        var lines = 0
        var cut: Int?
        var glyph = 0
        let glyphCount = layoutManager.numberOfGlyphs
        while glyph < glyphCount {
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
            lines += 1
            if lines == maxLines {
                cut = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil).upperBound
            }
            if lines > maxLines { break }
            glyph = NSMaxRange(lineRange)
        }
        guard lines > maxLines, let cut else { return string }
        var prefix = String((string as NSString).substring(to: cut))
        // Spazio per «…» sull'ultima riga: toglie l'ultima parola, poi gli spazi.
        if let space = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lastIndex(where: \.isWhitespace) {
            prefix = String(prefix[..<space])
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    var height: CGFloat {
        Self.padding + Self.cornerClearance + Self.headerHeight + Self.spacing + textHeight
            + (asksChoice ? Self.spacing + Self.choiceHeight : 0)
    }
    var typingDuration: TimeInterval { Double(count) / Self.charactersPerSecond }

    func typedCount(elapsed: TimeInterval) -> Int {
        max(0, min(count, Int(elapsed * Self.charactersPerSecond)))
    }

    /// Fine dell'ultimo carattere scritto, nel riquadro del testo (origine in alto a sinistra).
    func caret(after n: Int) -> CGPoint {
        carets[max(0, min(n, count))]
    }
}

/// Fumetto sopra il globo. Il testo compare un carattere alla volta; la parte non ancora
/// scritta è già impaginata ma trasparente, così le parole non saltano di riga.
struct VoxCard: View {
    var layout: VoxLayout
    var textScale: CGFloat = MascotMetrics.textScale
    var buttonScale: CGFloat = MascotMetrics.buttonScale
    var typingStart: TimeInterval
    var animating: Bool
    var surface: Surface
    var remaining: Int
    var previous: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: VoxLayout.spacing) {
            HStack {
                Text(title)
                    .font(.system(size: 11 * MascotMetrics.textScale, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(badge)
                    .font(.system(size: 11 * MascotMetrics.textScale))
                    .foregroundStyle(.tertiary)
            }
            // L'intestazione sta in alto, all'altezza della X: si ferma prima del suo angolo.
            .padding(.trailing, VoxLayout.cornerClearance - VoxLayout.padding)
            .frame(height: VoxLayout.headerHeight)

            // 30 aggiornamenti al secondo bastano: la scrittura avanza di pochi caratteri.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating || reduceMotion)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate - typingStart
                Text(typed(reduceMotion ? layout.count : layout.typedCount(elapsed: elapsed)))
                    .font(.system(size: VoxLayout.fontSize))
                    .foregroundStyle(.primary)
                    .frame(width: VoxLayout.width - 2 * VoxLayout.padding, height: layout.textHeight, alignment: .topLeading)
            }

            if layout.asksChoice {
                // Solo disegno: i clic li prendono i bersagli AppKit sopra, come per X e frecce.
                HStack(spacing: VoxLayout.choiceSpacing) {
                    Spacer(minLength: 0)
                    ChoicePill(title: layout.vox.noTitle, prominent: false, width: VoxLayout.noWidth, scale: textScale)
                    ChoicePill(title: layout.vox.yesTitle, prominent: true, width: VoxLayout.yesWidth, scale: textScale)
                }
                .frame(height: VoxLayout.choiceHeight)
            }
        }
        .padding([.top, .horizontal], VoxLayout.padding)
        .padding(.bottom, VoxLayout.cornerClearance)
        .frame(width: VoxLayout.width, height: layout.height, alignment: .topLeading)
        .background { CardBackground(surface: surface) }
        .overlay(alignment: .topTrailing) {
            VoxCornerChrome(surface: surface, symbol: "xmark", scale: buttonScale)
                .offset(x: 3 * buttonScale, y: -3 * buttonScale)
        }
        .overlay(alignment: .bottomTrailing) {
            if remaining > 0 {
                VoxCornerChrome(surface: surface, symbol: "chevron.forward", badge: remaining, scale: buttonScale)
                    .offset(x: 3 * buttonScale, y: 3 * buttonScale)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if previous > 0 {
                VoxCornerChrome(surface: surface, symbol: "chevron.backward", badge: previous, badgeEdge: .trailing, scale: buttonScale)
                    .offset(x: -3 * buttonScale, y: 3 * buttonScale)
            }
        }
        .environment(\.colorScheme, surface.isGlass ? colorScheme : .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(layout.text)
    }

    private var title: String {
        switch layout.kind {
        case .greeting: "Globy"
        case .publication: "Nuovo VOX"
        case .recent: "VOX recente"
        case .preview: "Anteprima"
        }
    }

    private var badge: String {
        switch layout.kind {
        case .greeting: "ciao"
        case .publication: "ora"
        case .recent: "già uscito"
        case .preview: "dimensioni"
        }
    }

    private func typed(_ n: Int) -> AttributedString {
        var string = AttributedString(layout.text)
        let split = string.characters.index(string.startIndex, offsetBy: n)
        string[split..<string.endIndex].foregroundColor = .clear
        return string
    }
}

/// Pulsante del fumetto disegnato in SwiftUI; il clic è in AppKit.
struct ChoicePill: View {
    var title: String
    var prominent: Bool
    var width: CGFloat
    var scale: CGFloat = MascotMetrics.textScale

    var body: some View {
        Text(title)
            .font(.system(size: 11.5 * scale, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? Color(white: 0.1) : .primary)
            .frame(width: width, height: 24 * scale)
            .background {
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(.white.opacity(0.92)) : AnyShapeStyle(.white.opacity(0.14)))
            }
            .allowsHitTesting(false)
    }
}

/// Disco d'angolo: stesso vetro di fumetto e sfera. Il clic è in AppKit.
struct VoxCornerChrome: View {
    var surface: Surface
    var symbol: String
    var badge: Int = 0
    var badgeEdge: HorizontalAlignment = .leading
    /// Esplicita: con una statica SwiftUI non ridisegnerebbe il disco quando cambia.
    var scale: CGFloat = MascotMetrics.buttonScale

    var body: some View {
        let size = 22 * scale
        let r = size / 2
        ZStack {
            if surface.isGlass {
                GlassPanelView(surface: surface, cornerRadius: r)
                    .id(surface)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
            } else {
                Circle()
                    .fill(Color(white: 0.08).opacity(0.92))
                    .overlay { Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5) }
            }
            Image(systemName: symbol)
                .font(.system(size: 8 * scale, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(surface.isGlass ? 0.45 : 0), radius: 1.2)
        }
        .frame(width: size, height: size)
        .overlay(alignment: badgeEdge == .leading ? .topLeading : .topTrailing) {
            if badge > 0 {
                let k = scale
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: (badge > 9 ? 7 : 8) * k, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.12))
                    .padding(.horizontal, badge > 9 ? 3.5 * k : 0)
                    .frame(minWidth: 13 * k, minHeight: 13 * k)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.95))
                            .overlay { Capsule(style: .continuous).strokeBorder(.black.opacity(0.14), lineWidth: 0.5) }
                    }
                    .offset(x: (badgeEdge == .leading ? -4 : 4) * k, y: -4 * k)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Bersaglio di clic trasparente sopra un disco d'angolo disegnato in SwiftUI.
final class VoxCornerButton: NSView {
    nonisolated static var size: CGFloat { 22 * MascotMetrics.buttonScale }
    nonisolated static var outset: CGFloat { 3 * MascotMetrics.buttonScale }

    var action: () -> Void = {}

    init(frame: NSRect, tooltip: String, accessibilityLabel: String) {
        super.init(frame: frame)
        toolTip = tooltip
        setAccessibilityRole(.button)
        setAccessibilityLabel(accessibilityLabel)
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action() }
    }

    var screenFrame: CGRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

private struct CardBackground: View {
    var surface: Surface
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        if surface.isGlass {
            GlassPanelView(surface: surface, cornerRadius: 18)
                .id(surface)
                .clipShape(shape)
                .overlay { shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5) }
        } else {
            shape.fill(Color(white: 0.08).opacity(0.92))
                .overlay { shape.strokeBorder(.white.opacity(0.1), lineWidth: 0.5) }
        }
    }
}

/// Vetro di sistema con angoli arrotondati: Liquid Glass su macOS 26, altrimenti smerigliato.
struct GlassPanelView: NSViewRepresentable {
    var surface: Surface
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        Self.makeNSView(surface: surface)
    }

    func updateNSView(_ view: NSView, context: Context) {
        if #available(macOS 26, *), let glass = view as? NSGlassEffectView {
            glass.style = surface == .clearGlass ? .clear : .regular
            glass.cornerRadius = cornerRadius
        } else if let blur = view as? NSVisualEffectView {
            blur.wantsLayer = true
            blur.layer?.cornerRadius = cornerRadius
            blur.layer?.masksToBounds = true
        }
    }

    static func makeNSView(surface: Surface) -> NSView {
        if #available(macOS 26, *), surface == .liquidGlass || surface == .clearGlass {
            let glass = NSGlassEffectView()
            glass.contentView = NSView()
            glass.style = surface == .clearGlass ? .clear : .regular
            return glass
        }
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        return blur
    }
}
