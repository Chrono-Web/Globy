import Foundation
import Testing
@testable import GlobyCore

@Suite("Baseline")
struct BaselineTests {
    @Test("il primo avvio salva il RSS e non notifica l'archivio")
    func firstLaunchDoesNotNotify() async throws {
        let client = FakeChronocol()
        await client.setRSS([
            remote("c", hours: -1),
            remote("b", hours: -2),
            remote("a", hours: -3)
        ])
        let (coordinator, store, _) = makeCoordinator(client: client)

        let report = await coordinator.synchronize(cause: .wake)

        #expect(report.cause == .firstLaunch)
        #expect(report.completedBaseline)
        #expect(report.usedRSS)
        #expect(!report.usedJSON)
        #expect(report.notifications.isEmpty)
        #expect(report.changes.filter { if case .published = $0 { true } else { false } }.count == 3)
        #expect(await client.listPagesRequested.isEmpty)

        let snapshot = await store.snapshot()
        #expect(snapshot.hasCompletedBaseline)
        #expect(snapshot.records.count == 3)
        #expect(snapshot.records.values.allSatisfy { $0.notifiedAt == nil })
        #expect(snapshot.lastSuccessfulSyncAt == T.t0)
    }

    @Test("un fallimento al primo avvio non chiude la baseline")
    func failedFirstLaunchLeavesBaselineOpen() async throws {
        let client = FakeChronocol()
        await client.failRSS(times: 5)
        let (coordinator, store, _) = makeCoordinator(client: client)

        let report = await coordinator.synchronize(cause: .wake)
        let snapshot = await store.snapshot()

        #expect(report.failure?.kind == .offline)
        #expect(!snapshot.hasCompletedBaseline)
        #expect(snapshot.records.isEmpty)
    }
}
