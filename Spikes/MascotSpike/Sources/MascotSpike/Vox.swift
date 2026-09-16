import AppKit
import SwiftUI

/// VOX di esempio per il richiamo manuale. Nello spike non c'è sincronizzazione:
/// il testo è una fixture scritta a mano. Il permalink apre Chronocol nel browser.
struct Vox: Equatable {
    enum Kind {
        case publication
        case greeting
    }

    var text: String
    var permalink: URL
    var kind: Kind = .publication

    /// Saluto di primo avvio: non è una VOX e non nasce dalla sincronizzazione.
    static let greeting = Vox(
        text: "Ciao, sono Globy, la mascotte di Chronocol. Quando esce una nuova VOX vengo un attimo qui, in basso a destra.",
        permalink: URL(string: "https://chronocol.com/it")!,
        kind: .greeting
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
        text: "Prima VOX di coda (fixture). Se ce n'è un'altra, in basso a destra compare la freccia.",
        permalink: URL(string: "https://chronocol.com/it")!
    )

    static let sampleShortB = Vox(
        text: "Terza VOX di coda (fixture). La X chiude solo il fumetto; la freccia passa alla successiva.",
        permalink: URL(string: "https://chronocol.com/it")!
    )

    static let burst = [sampleShortA, sample, sampleShortB]
}

/// Impaginazione della card calcolata con TextKit: altezza fissa fin dall'inizio e
/// posizione del carattere appena scritto, che gli occhi seguono.
@MainActor
final class VoxLayout {
    static let width: CGFloat = 330
    static let padding: CGFloat = 14
    static let headerHeight: CGFloat = 14
    static let spacing: CGFloat = 8
    static let fontSize: CGFloat = 12.5
    static let charactersPerSecond = 80.0

    let kind: Vox.Kind
    let text: String
    let count: Int
    let textHeight: CGFloat
    /// Fine di ogni carattere, calcolata una volta sola: `carets[n]` segue l'n-esimo.
    private let carets: [CGPoint]

    init(_ vox: Vox) {
        kind = vox.kind
        text = vox.text
        count = vox.text.count
        let font = NSFont.systemFont(ofSize: Self.fontSize)
        let storage = NSTextStorage(string: vox.text, attributes: [.font: font])
        let container = NSTextContainer(size: CGSize(width: Self.width - 2 * Self.padding, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        textHeight = ceil(layoutManager.usedRect(for: container).height)

        var carets = [CGPoint(x: 0, y: layoutManager.defaultLineHeight(for: font) / 2)]
        var index = vox.text.startIndex
        while index < vox.text.endIndex {
            let next = vox.text.index(after: index)
            let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(index..<next, in: vox.text), actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
            carets.append(CGPoint(x: rect.maxX, y: rect.midY))
            index = next
        }
        self.carets = carets
    }

    var height: CGFloat { 2 * Self.padding + Self.headerHeight + Self.spacing + textHeight }
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
                Text(layout.kind == .greeting ? "Globy" : "Nuova VOX")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(layout.kind == .greeting ? "ciao" : "ora")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.trailing, 16)
            .frame(height: VoxLayout.headerHeight)

            // 30 aggiornamenti al secondo bastano: la scrittura avanza di pochi caratteri.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating || reduceMotion)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate - typingStart
                Text(typed(reduceMotion ? layout.count : layout.typedCount(elapsed: elapsed)))
                    .font(.system(size: VoxLayout.fontSize))
                    .foregroundStyle(.primary)
                    .frame(width: VoxLayout.width - 2 * VoxLayout.padding, height: layout.textHeight, alignment: .topLeading)
            }
        }
        .padding(VoxLayout.padding)
        .frame(width: VoxLayout.width, height: layout.height, alignment: .topLeading)
        .background { CardBackground(surface: surface) }
        .overlay(alignment: .topTrailing) {
            VoxCornerChrome(surface: surface, symbol: "xmark")
                .offset(x: VoxCornerButton.outset, y: -VoxCornerButton.outset)
        }
        .overlay(alignment: .bottomTrailing) {
            if remaining > 0 {
                VoxCornerChrome(surface: surface, symbol: "chevron.forward", badge: remaining)
                    .offset(x: VoxCornerButton.outset, y: VoxCornerButton.outset)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if previous > 0 {
                VoxCornerChrome(surface: surface, symbol: "chevron.backward", badge: previous, badgeEdge: .trailing)
                    .offset(x: -VoxCornerButton.outset, y: VoxCornerButton.outset)
            }
        }
        .environment(\.colorScheme, surface.isGlass ? colorScheme : .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(layout.text)
    }

    private func typed(_ n: Int) -> AttributedString {
        var string = AttributedString(layout.text)
        let split = string.characters.index(string.startIndex, offsetBy: n)
        string[split..<string.endIndex].foregroundColor = .clear
        return string
    }
}

/// Disco d'angolo: stesso vetro di fumetto e sfera. Il clic è in AppKit.
struct VoxCornerChrome: View {
    var surface: Surface
    var symbol: String
    var badge: Int = 0
    var badgeEdge: HorizontalAlignment = .leading

    var body: some View {
        let r = VoxCornerButton.size / 2
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
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(surface.isGlass ? 0.45 : 0), radius: 1.2)
        }
        .frame(width: VoxCornerButton.size, height: VoxCornerButton.size)
        .overlay(alignment: badgeEdge == .leading ? .topLeading : .topTrailing) {
            if badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: badge > 9 ? 7 : 8, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.12))
                    .padding(.horizontal, badge > 9 ? 3.5 : 0)
                    .frame(minWidth: 13, minHeight: 13)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.95))
                            .overlay { Capsule(style: .continuous).strokeBorder(.black.opacity(0.14), lineWidth: 0.5) }
                    }
                    .offset(x: badgeEdge == .leading ? -4 : 4, y: -4)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Bersaglio di clic trasparente sopra un disco d'angolo disegnato in SwiftUI.
final class VoxCornerButton: NSView {
    static let size: CGFloat = 22
    static let outset: CGFloat = 3

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
