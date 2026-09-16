import Foundation
import Testing
@testable import GlobyCore

@Suite("Store su file")
struct FileContentStoreTests {
    @Test("sopravvive a un nuovo avvio e reset cancella il file")
    func roundTripAndReset() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "globy-store-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let first = FileContentStore(fileURL: url)
        let record = VoxRecord(
            documentId: "a",
            permalink: URL(string: "https://chronocol.test/it/vox/a")!,
            listText: "ciao",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            fingerprint: "fp",
            firstObservedAt: Date(timeIntervalSince1970: 200),
            lastObservedAt: Date(timeIntervalSince1970: 200),
            notifiedAt: Date(timeIntervalSince1970: 200)
        )
        await first.apply(StoreTransaction(upserts: [record], lastSuccessfulSyncAt: Date(timeIntervalSince1970: 200), hasCompletedBaseline: true))

        let second = FileContentStore(fileURL: url)
        let snap = await second.snapshot()
        #expect(snap.hasCompletedBaseline)
        #expect(snap.records["a"]?.listText == "ciao")
        #expect(snap.records["a"]?.notifiedAt != nil)

        await second.reset()
        let empty = await FileContentStore(fileURL: url).snapshot()
        #expect(empty.records.isEmpty)
        #expect(!empty.hasCompletedBaseline)
    }
}
