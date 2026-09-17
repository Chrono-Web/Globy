// Disegna lo sfondo della finestra del DMG (660 × 480 pt) in 1x e 2x.
// Uso: swift scripts/dmg/sfondo.swift <cartella di uscita>
import AppKit

let size = NSSize(width: 660, height: 480)
let out = URL(fileURLWithPath: CommandLine.arguments[1])

func render(scale: CGFloat, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    // Coordinate con l'origine in alto, come la finestra del Finder.
    context.cgContext.translateBy(x: 0, y: size.height)
    context.cgContext.scaleBy(x: 1, y: -1)

    let bounds = NSRect(origin: .zero, size: size)
    NSGradient(colors: [NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 1),
                        NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.97, alpha: 1)])!
        .draw(in: bounds, angle: -90)

    func text(_ string: String, size fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let height = attributed.boundingRect(with: NSSize(width: size.width - 80, height: 200), options: .usesLineFragmentOrigin).height
        // Il testo va disegnato non capovolto: contesto locale riflesso attorno alla riga.
        let cg = context.cgContext
        cg.saveGState()
        cg.translateBy(x: 0, y: y + height)
        cg.scaleBy(x: 1, y: -1)
        attributed.draw(with: NSRect(x: 40, y: 0, width: size.width - 80, height: height), options: .usesLineFragmentOrigin)
        cg.restoreGState()
    }

    let ink = NSColor(calibratedWhite: 0.13, alpha: 1)
    let soft = NSColor(calibratedWhite: 0.38, alpha: 1)
    text("Installa Globy", size: 26, weight: .semibold, color: ink, y: 34)
    text("Trascina Globy nella cartella Applicazioni", size: 14, weight: .regular, color: soft, y: 72)

    // Freccia tra le due icone (centri a x 170 e 490, y 200).
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 262, y: 200))
    arrow.line(to: NSPoint(x: 390, y: 200))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    NSColor(calibratedRed: 0.36, green: 0.45, blue: 0.62, alpha: 0.85).setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 376, y: 186))
    head.line(to: NSPoint(x: 396, y: 200))
    head.line(to: NSPoint(x: 376, y: 214))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Riga sottile sopra le istruzioni (installare, aggiornare, disinstallare).
    NSColor(calibratedWhite: 0, alpha: 0.08).setFill()
    NSRect(x: 60, y: 290, width: size.width - 120, height: 1).fill()

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

render(scale: 1, to: out.appendingPathComponent("sfondo.png"))
render(scale: 2, to: out.appendingPathComponent("sfondo@2x.png"))
