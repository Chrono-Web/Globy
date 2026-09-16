import AppKit
import SwiftUI

/// VOX di esempio per il richiamo manuale. Nello spike non c'è sincronizzazione:
/// il testo è una fixture scritta a mano, non letta da Chronocol.
struct Vox: Equatable {
    var text: String

    static let sample = Vox(text: """
    ⚡️🇵🇸🏚️ A six‑storey building housing ten families collapsed in Gaza City due to structural damage caused by previous Israeli bombings, killing at least twelve people and leaving a dozen survivors rescued by rescuers.

    🔻 Palestinian Civil Protection reports that dozens of people remain trapped under the rubble, including about fifty children.

    🔻 Rescue operations are also severely hampered by the lack of heavy equipment to remove the rubble, due to the entry bans imposed by Israel since October 7.
    """)
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

    let text: String
    let count: Int
    let textHeight: CGFloat
    /// Fine di ogni carattere, calcolata una volta sola: `carets[n]` segue l'n-esimo.
    private let carets: [CGPoint]

    init(_ vox: Vox) {
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: VoxLayout.spacing) {
            HStack {
                Text("Nuova VOX")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("ora")
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
            VoxCloseChrome(surface: surface)
                .offset(x: 3, y: -3)
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

/// Disco della X: stesso `GlassPanelView` di fumetto e sfera. Il clic è in AppKit.
struct VoxCloseChrome: View {
    var surface: Surface

    var body: some View {
        let r = VoxCloseButton.size / 2
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
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(surface.isGlass ? 0.45 : 0), radius: 1.2)
        }
        .frame(width: VoxCloseButton.size, height: VoxCloseButton.size)
        .allowsHitTesting(false)
    }
}

/// Bersaglio di clic trasparente sopra la X disegnata in SwiftUI.
final class VoxCloseButton: NSView {
    static let size: CGFloat = 22

    var action: () -> Void = {}

    override init(frame: NSRect) {
        super.init(frame: frame)
        toolTip = "Chiudi"
        setAccessibilityRole(.button)
        setAccessibilityLabel("Chiudi")
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
