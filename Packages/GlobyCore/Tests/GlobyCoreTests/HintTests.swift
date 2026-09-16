import Foundation
import Testing
@testable import GlobyCore

@Suite("Hint SSE")
struct HintTests {
    @Test("un evento SSE non è un VOX nuovo se HTTP non lo conferma")
    func sseIsNotAuthoritative() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("known", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        await client.setDetail("ghost", nil)
        let report = await coordinator.handleHint(.voxNew(documentId: "ghost", createdAt: T.hours(0.5)))
        let snapshot = await store.snapshot()

        #expect(report.changes.isEmpty)
        #expect(report.notifications.isEmpty)
        #expect(snapshot.records["ghost"] == nil)
        #expect(await client.detailsRequested == ["ghost"])
        #expect(await client.fetchRSSCount == 2)
    }

    @Test("due hint duplicati producono una sola notifica")
    func duplicateHintsDoNotDuplicateNotifications() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("known", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        let fresh = remote("fresh", hours: 1)
        clock.setNow(T.hours(2))
        await client.setRSS([fresh, remote("known", hours: -1)])
        await client.setDetail("fresh", fresh)

        let first = await coordinator.handleHint(.voxNew(documentId: "fresh", createdAt: T.hours(1)))
        let second = await coordinator.handleHint(.voxNew(documentId: "fresh", createdAt: T.hours(1)))
        let snapshot = await store.snapshot()

        #expect(first.notifications == [.newVox(documentId: "fresh")])
        #expect(second.notifications.isEmpty)
        #expect(second.changes.isEmpty)
        #expect(snapshot.records["fresh"]?.notifiedAt == T.hours(2))
    }

    @Test("un 503 dello stream fa fallback al catch-up HTTP senza svuotare lo store")
    func stream503FallsBackWithoutWipingStore() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("kept", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        let report = await coordinator.handleHint(.streamUnavailable(statusCode: 503))
        let snapshot = await store.snapshot()

        #expect(report.streamFallback)
        #expect(report.cause == .polling)
        #expect(report.failure == nil)
        #expect(snapshot.records["kept"] != nil)
        #expect(snapshot.hasCompletedBaseline)
    }

    @Test("un ritiro si conferma solo con 404 sul dettaglio HTTP")
    func withdrawalRequiresHTTP404() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("gone", hours: -1), remote("stay", hours: -2)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        await client.setRSS([remote("stay", hours: -2)])
        await client.setDetail("gone", nil)
        let report = await coordinator.handleHint(.voxUpdated(documentId: "gone"))
        let snapshot = await store.snapshot()

        #expect(report.changes == [.withdrawn(documentId: "gone")])
        #expect(snapshot.records["gone"]?.isAvailable == false)
        #expect(snapshot.records["stay"]?.isAvailable == true)
        #expect(report.notifications.isEmpty)
    }

    @Test("un SSE malformato non autorizza cambiamenti")
    func malformedSSEDoesNotChangeState() async throws {
        let text = try String(data: fixtureData("sse-malformed", ext: "txt"), encoding: .utf8)
        let events = SSEParser.parse(try #require(text))
        #expect(events.contains(.malformed))
        #expect(events.contains(.unknown(event: "mystery")))

        let client = FakeChronocol()
        await client.setRSS([remote("known", hours: -1)])
        let (coordinator, store, _) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)
        let report = await coordinator.handleHint(.malformed)
        let snapshot = await store.snapshot()

        #expect(report.changes.isEmpty)
        #expect(await client.fetchRSSCount == 1)
        #expect(snapshot.records.count == 1)
    }
}
