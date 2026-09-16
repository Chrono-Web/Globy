import Foundation
import Testing
@testable import GlobyCore

@Suite("Catch-up")
struct CatchUpTests {
    @Test("un RSS che copre lastSuccessfulSyncAt non legge il JSON")
    func rssThatCoversDoesNotFetchJSON() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("a", hours: -3), remote("b", hours: -2), remote("c", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(2))
        await client.setRSS([
            remote("d", hours: 1),
            remote("c", hours: -1)
        ])
        let report = await coordinator.synchronize(cause: .wake)
        let snapshot = await store.snapshot()

        #expect(!report.usedJSON)
        #expect(report.jsonPagesFetched == 0)
        #expect(report.notifications == [.newVox(documentId: "d")])
        #expect(snapshot.records["d"]?.notifiedAt == T.hours(2))
        #expect(await client.listPagesRequested.isEmpty)
    }

    @Test("un RSS troppo corto pagina il JSON fino a coprire il buco")
    func shortRSSPaginatesJSONUntilCursor() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("old-a", hours: -30), remote("old-b", hours: -29)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(10))
        await client.setRSS([
            remote("new-2", hours: 9),
            remote("new-1", hours: 8)
        ])
        await client.setPages([
            1: page(1, of: 2, items: [remote("new-2", hours: 9), remote("new-1", hours: 8)]),
            2: page(2, of: 2, items: [remote("mid", hours: 1), remote("old-b", hours: -29)])
        ])

        let report = await coordinator.synchronize(cause: .reconnect)
        let snapshot = await store.snapshot()

        #expect(report.usedJSON)
        #expect(report.jsonPagesFetched == 2)
        #expect(await client.listPagesRequested == [1, 2])
        #expect(Set(report.notifications.flatMap(\.ids)) == Set(["new-2", "new-1", "mid"]))
        #expect(snapshot.records["mid"] != nil)
        #expect(snapshot.records["old-a"]?.isAvailable == true)
    }

    @Test("un VOX assente dal solo RSS non è un ritiro")
    func missingFromRSSIsNotWithdrawal() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("keep", hours: -2), remote("drop-from-feed", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        await client.setRSS([remote("keep", hours: -2), remote("newer", hours: 0.5)])
        let report = await coordinator.synchronize(cause: .wake)
        let snapshot = await store.snapshot()

        #expect(!report.changes.contains(.withdrawn(documentId: "drop-from-feed")))
        #expect(snapshot.records["drop-from-feed"]?.isAvailable == true)
        #expect(report.notifications == [.newVox(documentId: "newer")])
    }

    @Test("un aggiornamento di un VOX già letto non è una nuova pubblicazione")
    func updateOfReadVoxIsNotNewPublication() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("vox", hours: -1, text: "versione 1")])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)
        await store.markRead(documentId: "vox", at: T.hours(-0.5))

        clock.setNow(T.hours(1))
        let updated = remote("vox", hours: -1, text: "versione 2", updatedHours: 0.5)
        await client.setRSS([updated])
        await client.setDetail("vox", updated)
        let report = await coordinator.handleHint(.voxUpdated(documentId: "vox"))
        let snapshot = await store.snapshot()

        #expect(report.changes == [.updated(documentId: "vox")])
        #expect(report.notifications.isEmpty)
        #expect(snapshot.records["vox"]?.readAt == T.hours(-0.5))
        #expect(snapshot.records["vox"]?.listText == "versione 2")
    }

    @Test("se il JSON non copre il buco il cursore non avanza")
    func incompleteJSONDoesNotAdvanceCursor() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("old", hours: -40)])
        let configuration = testConfiguration(maxJSONPages: 1)
        let (coordinator, store, clock) = makeCoordinator(client: client, configuration: configuration)
        _ = await coordinator.synchronize(cause: .wake)
        let cursor = await store.snapshot().lastSuccessfulSyncAt

        clock.setNow(T.hours(5))
        await client.setRSS([remote("new", hours: 4)])
        await client.setPages([
            1: page(1, of: 3, items: [remote("new", hours: 4), remote("newer", hours: 3)], total: 6)
        ])
        let report = await coordinator.synchronize(cause: .wake)
        let snapshot = await store.snapshot()

        #expect(report.failure?.kind == .incompleteCatchUp)
        #expect(snapshot.lastSuccessfulSyncAt == cursor)
    }
}

private extension NotificationDecision {
    var ids: [String] {
        switch self {
        case .newVox(let documentId):
            return [documentId]
        case .summary(let documentIds):
            return documentIds
        }
    }
}
