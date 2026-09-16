import Foundation

/// Chronocol in processo per l'MVP: nessuna rete. `publish` simula un nuovo VOX.
public actor FixtureChronocol: ChronocolReading {
    public private(set) var rss: [RemoteVox]
    public private(set) var fetchRSSCount = 0

    public init(rss: [RemoteVox] = FixtureChronocol.seed) {
        self.rss = rss
    }

    public func publish(_ vox: RemoteVox) {
        rss.insert(vox, at: 0)
    }

    public func fetchRSS() async throws -> [RemoteVox] {
        fetchRSSCount += 1
        return rss
    }

    public func fetchListPage(page: Int) async throws -> VoxListPage {
        let pageSize = 25
        return VoxListPage(
            items: rss,
            page: page,
            pageSize: pageSize,
            pageCount: 1,
            total: rss.count
        )
    }

    public func fetchDetail(documentId: String) async throws -> RemoteVox? {
        rss.first { $0.documentId == documentId }
    }

    public static let seed: [RemoteVox] = [
        RemoteVox(
            documentId: "fixture-baseline-1",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "VOX di baseline (fixture). Al primo avvio non genera notifica.",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        RemoteVox(
            documentId: "fixture-baseline-2",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Secondo VOX già presente all'avvio. Resta visibile nel menu.",
            createdAt: Date(timeIntervalSince1970: 1_799_996_400),
            updatedAt: Date(timeIntervalSince1970: 1_799_996_400)
        ),
        RemoteVox(
            documentId: "fixture-baseline-3",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Terzo VOX della fixture, più lungo: serve a vedere un fumetto su più righe quando il globo presenta i VOX recenti al primo avvio, senza toccare la rete.",
            createdAt: Date(timeIntervalSince1970: 1_799_992_800),
            updatedAt: Date(timeIntervalSince1970: 1_799_992_800)
        ),
        RemoteVox(
            documentId: "fixture-baseline-4",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Quarto VOX (fixture). Breve.",
            createdAt: Date(timeIntervalSince1970: 1_799_989_200),
            updatedAt: Date(timeIntervalSince1970: 1_799_989_200)
        ),
        RemoteVox(
            documentId: "fixture-baseline-5",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Quinto VOX della fixture: l'ultimo che il primo avvio propone di mostrare.",
            createdAt: Date(timeIntervalSince1970: 1_799_985_600),
            updatedAt: Date(timeIntervalSince1970: 1_799_985_600)
        ),
        RemoteVox(
            documentId: "fixture-baseline-6",
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Sesto VOX (fixture). Sta nel menu ma resta fuori dalla presentazione dei cinque.",
            createdAt: Date(timeIntervalSince1970: 1_799_982_000),
            updatedAt: Date(timeIntervalSince1970: 1_799_982_000)
        )
    ]

    public static func makePublication(at date: Date = Date()) -> RemoteVox {
        let id = "fixture-new-\(Int(date.timeIntervalSince1970))"
        return RemoteVox(
            documentId: id,
            permalink: URL(string: "https://chronocol.com/it")!,
            listText: "Nuovo VOX simulato. Il globo compare solo dopo questa conferma locale.",
            createdAt: date,
            updatedAt: date
        )
    }
}
