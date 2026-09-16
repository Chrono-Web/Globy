import CoreGraphics
import Foundation

/// Posizione locale (AppKit, origine in basso a sinistra) di globo e fumetto nella finestra.
@MainActor
struct MascotPlacement: Equatable {
    var size: CGSize
    var globe: CGRect
    var card: CGRect?
    var cardAbove: Bool

    static let empty = MascotPlacement(
        size: MascotLayout.globeArea,
        globe: CGRect(origin: .zero, size: MascotLayout.globeArea),
        card: nil,
        cardAbove: true
    )

    /// Centro di un rettangolo AppKit nel sistema SwiftUI della stessa vista (origine in alto a sinistra).
    func swiftUICenter(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: size.height - rect.midY)
    }
}

/// Il globo è l'ancora a schermo. Il fumetto lo segue: di preferenza sopra e centrato,
/// sotto se in alto non c'è spazio, e sempre interamente nella `visibleFrame`.
@MainActor
enum MascotLayout {
    static let globeArea = CGSize(width: 160, height: 160)
    static let globeDrawn: CGFloat = 116
    /// Distanza tra il disco disegnato e il bordo del fumetto.
    static let cardGap: CGFloat = 10
    static let margin: CGFloat = 16

    /// Dal bordo visibile al centro del globo, nella posa di default in basso a destra.
    static var defaultPad: CGFloat {
        margin + (globeArea.width - globeDrawn) / 2 + globeDrawn / 2
    }

    static var cardSafeInset: CGFloat { margin + VoxCornerButton.outset }

    static func defaultGlobeCenter(in visible: CGRect) -> CGPoint {
        CGPoint(x: visible.maxX - defaultPad, y: visible.minY + defaultPad)
    }

    /// Il disco disegnato resta a `margin` pt dal bordo visibile.
    static func clampGlobeCenter(_ center: CGPoint, in visible: CGRect) -> CGPoint {
        let r = globeDrawn / 2
        let inset = visible.insetBy(dx: margin, dy: margin)
        guard inset.width >= globeDrawn, inset.height >= globeDrawn else {
            return CGPoint(x: visible.midX, y: visible.midY)
        }
        return CGPoint(
            x: min(max(center.x, inset.minX + r), inset.maxX - r),
            y: min(max(center.y, inset.minY + r), inset.maxY - r)
        )
    }

    static func globeAreaScreen(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - globeArea.width / 2,
            y: center.y - globeArea.height / 2,
            width: globeArea.width,
            height: globeArea.height
        )
    }

    /// Preferisce sopra il globo e centrato in orizzontale; se non entra, scende sotto
    /// o si sposta verso il centro dello schermo.
    static func placeCard(height: CGFloat, globeCenter: CGPoint, visible: CGRect) -> (frame: CGRect, above: Bool) {
        let r = globeDrawn / 2
        let safe = visible.insetBy(dx: cardSafeInset, dy: cardSafeInset)
        let width = min(VoxLayout.width, max(safe.width, 1))
        let fittedHeight = min(max(height, 1), max(safe.height, 1))
        let globeTop = globeCenter.y + r
        let globeBottom = globeCenter.y - r
        let spaceAbove = safe.maxY - (globeTop + cardGap)
        let spaceBelow = (globeBottom - cardGap) - safe.minY
        let above: Bool
        if fittedHeight <= spaceAbove {
            above = true
        } else if fittedHeight <= spaceBelow {
            above = false
        } else {
            above = spaceAbove >= spaceBelow
        }

        var x = globeCenter.x - width / 2
        let maxX = max(safe.minX, safe.maxX - width)
        x = min(max(x, safe.minX), maxX)

        var y: CGFloat
        if above {
            y = globeTop + cardGap
            y = min(y, safe.maxY - fittedHeight)
            y = max(y, safe.minY)
        } else {
            y = globeBottom - cardGap - fittedHeight
            y = max(y, safe.minY)
            y = min(y, safe.maxY - fittedHeight)
        }
        return (CGRect(x: x, y: y, width: width, height: fittedHeight), above)
    }

    static func windowFrame(globeCenter: CGPoint, card: CGRect?) -> CGRect {
        var rect = globeAreaScreen(center: globeCenter)
        if let card {
            let pad = VoxCornerButton.outset
            rect = rect.union(card.insetBy(dx: -pad, dy: -pad))
        }
        return rect.integral
    }

    static func placement(globeCenter: CGPoint, cardHeight: CGFloat?, visible: CGRect) -> (window: CGRect, placement: MascotPlacement, center: CGPoint) {
        let center = clampGlobeCenter(globeCenter, in: visible)
        let card: CGRect?
        let above: Bool
        if let cardHeight {
            let placed = placeCard(height: cardHeight, globeCenter: center, visible: visible)
            card = placed.frame
            above = placed.above
        } else {
            card = nil
            above = true
        }
        let window = windowFrame(globeCenter: center, card: card)
        let localGlobe = globeAreaScreen(center: center).offsetBy(dx: -window.minX, dy: -window.minY)
        let localCard = card.map { $0.offsetBy(dx: -window.minX, dy: -window.minY) }
        return (
            window,
            MascotPlacement(size: window.size, globe: localGlobe, card: localCard, cardAbove: above),
            center
        )
    }
}
