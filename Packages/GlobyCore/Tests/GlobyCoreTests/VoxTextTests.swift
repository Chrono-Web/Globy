import Testing
import GlobyCore

@Suite("Testo leggibile")
struct VoxTextTests {
    @Test("le fonti restano fuori")
    func dropsSources() {
        let text = "⚡️ Notizia.\n\n🔻 Dettaglio.\n\nFonti: https://a.example/x · https://b.example/y"
        #expect(VoxText.readable(text) == "⚡️ Notizia.\n\n🔻 Dettaglio.")
    }

    @Test("link markdown e URL nudi spariscono dal corpo")
    func cleansLinks() {
        #expect(VoxText.readable("Vedi [Reuters](https://reuters.com/x) oggi.") == "Vedi Reuters oggi.")
        #expect(VoxText.readable("Testo https://example.com/y fine.") == "Testo  fine.")
        #expect(VoxText.readable("A](https://x.example/z") == "A")
    }

    @Test("un testo fatto solo di fonti non diventa vuoto")
    func neverEmpty() {
        #expect(!VoxText.readable("Fonti: https://x.example").isEmpty)
    }
}
