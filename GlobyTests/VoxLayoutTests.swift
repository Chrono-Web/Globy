import AppKit
import GlobyCore
import Testing
@testable import Globy

@Suite("Fumetto")
@MainActor
struct VoxLayoutTests {
    private let longVox = """
    ⚡️🇵🇸🏚️ Un edificio di sei piani ospitante dieci famiglie è crollato a Gaza City a causa dei danni strutturali provocati dai precedenti bombardamenti israeliani, causando almeno dodici vittime e una dozzina di persone estratte vive dai soccorritori.

    🔻 La Protezione Civile palestinese riferisce che decine di persone risultano ancora disperse sotto i detriti, tra cui circa cinquanta bambini.

    🔻 Le operazioni di soccorso sono inoltre fortemente penalizzate dalla mancanza di mezzi pesanti per rimuovere le macerie, a causa dei divieti d'ingresso imposti da Israele dal 7 ottobre.

    Fonti: https://www.lemonde.fr/international/article/2026/09/16/a-gaza · https://www.bbc.co.uk/news/articles/cvp8d00j9gg5o
    """

    @Test("un VOX lungo perde le fonti e resta entro le righe massime")
    func longVoxIsCapped() {
        let layout = VoxLayout(Vox(record: record(longVox)))
        #expect(layout.text.hasSuffix("dal 7 ottobre."))
        #expect(!layout.text.contains("http"))
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: VoxLayout.fontSize))
        #expect(layout.textHeight <= lineHeight * CGFloat(VoxLayout.maxLines) + 4)
    }

    @Test("un VOX breve resta intero")
    func shortVoxIsUntouched() {
        let layout = VoxLayout(Vox(record: record("⚡️ Notizia breve.\n\nFonti: https://x.example")))
        #expect(layout.text == "⚡️ Notizia breve.")
    }

    private func record(_ text: String) -> VoxRecord {
        let now = Date()
        return VoxRecord(documentId: "t", permalink: URL(string: "https://chronocol.com/it")!, listText: text,
                         createdAt: now, updatedAt: now, fingerprint: "f", firstObservedAt: now, lastObservedAt: now)
    }
}
