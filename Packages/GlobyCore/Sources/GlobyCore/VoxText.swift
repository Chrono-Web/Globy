import Foundation

/// Testo di un VOX pronto da leggere in fumetto, menu e banner. Le fonti restano nel
/// VOX completo su Chronocol: qui sarebbero solo link lunghi e illeggibili.
public enum VoxText {
    public static func readable(_ text: String) -> String {
        var body = text
        // Tutto da «Fonti:» (o «Fonte:») a inizio riga in poi.
        if let range = body.range(of: #"(?im)^\s*fonti?\s*:"#, options: .regularExpression) {
            body = String(body[..<range.lowerBound])
        }
        // [etichetta](url) → etichetta; poi i resti di link spezzati e gli URL nudi.
        body = body.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)?"#, with: "$1", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\]?\(?https?://\S+"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }
}
