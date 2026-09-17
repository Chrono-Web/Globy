import CoreGraphics

/// Scala di testo e pulsanti di fumetto e mascotte. 1 = dimensioni standard.
/// La imposta `AppSession` dalle preferenze; si legge solo sul main thread.
enum MascotMetrics {
    nonisolated(unsafe) static var textScale: CGFloat = 1
    nonisolated(unsafe) static var buttonScale: CGFloat = 1
    nonisolated(unsafe) static var globeScale: CGFloat = 1

    static let textRange: ClosedRange<Double> = 0.85...1.5
    static let buttonRange: ClosedRange<Double> = 0.8...1.6
    static let globeRange: ClosedRange<Double> = 0.75...2.5
}
