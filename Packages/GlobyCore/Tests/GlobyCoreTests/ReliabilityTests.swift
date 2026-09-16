import Foundation
import Testing
@testable import GlobyCore

@Suite("Affidabilità")
struct ReliabilityTests {
    @Test("offline prolungato non cancella lo store e il retry recupera")
    func prolongedOfflineKeepsStoreThenRecovers() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("kept", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(3))
        await client.failRSS(times: 8)
        let failed = await coordinator.synchronize(cause: .wake)
        var snapshot = await store.snapshot()
        #expect(failed.failure?.kind == .offline)
        #expect(snapshot.records["kept"] != nil)
        #expect(snapshot.lastSuccessfulSyncAt == T.t0)

        await client.failRSS(times: 0)
        let recovered = remote("late", hours: 2)
        await client.setRSS([recovered, remote("kept", hours: -1)])
        let ok = await coordinator.synchronize(cause: .wake)
        snapshot = await store.snapshot()
        #expect(ok.failure == nil)
        #expect(ok.notifications == [.newVox(documentId: "late")])
        #expect(snapshot.lastSuccessfulSyncAt == T.hours(3))
    }

    @Test("il retry usa backoff e poi riesce")
    func retryBackoffThenSucceeds() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("a", hours: -1)])
        await client.failRSS(times: 2)
        let clock = ControllableClock()
        let (coordinator, _, _) = makeCoordinator(client: client, clock: clock)

        let report = await coordinator.synchronize(cause: .wake)

        #expect(report.failure == nil)
        #expect(report.completedBaseline)
        #expect(await client.fetchRSSCount == 3)
        #expect(clock.sleeps == [0.05, 0.1])
    }

    @Test("una risposta JSON incompatibile non cancella lo store")
    func incompatiblePayloadKeepsStore() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("kept", hours: -1)])
        let (coordinator, store, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        await client.failRSS(times: 1, error: ChronocolClientError.incompatiblePayload("JSON rotto"))
        let report = await coordinator.synchronize(cause: .wake)
        let snapshot = await store.snapshot()

        #expect(report.failure?.kind == .incompatiblePayload)
        #expect(snapshot.records["kept"] != nil)
        #expect(snapshot.lastSuccessfulSyncAt == T.t0)
        #expect(await client.fetchRSSCount == 2)
    }

    @Test("più risvegli ravvicinati producono una sola sincronizzazione in volo")
    func concurrentWakeCoalescesToOneFetch() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("a", hours: -1)])
        await client.setHoldFirstRSS(true)
        let (coordinator, _, _) = makeCoordinator(client: client)

        let first = Task { await coordinator.synchronize(cause: .wake) }
        await client.waitUntilRSSStarted()
        let second = Task { await coordinator.synchronize(cause: .reconnect) }
        await Task.yield()
        await client.releaseRSS()

        let report1 = await first.value
        let report2 = await second.value

        #expect(await client.fetchRSSCount == 1)
        #expect(!report1.coalesced)
        #expect(report2.coalesced)
        #expect(report1.completedBaseline)
        #expect(report2.completedBaseline)
    }

    @Test("una raffica diventa un riepilogo")
    func burstBecomesSummary() async throws {
        let client = FakeChronocol()
        await client.setRSS([remote("old", hours: -5)])
        let (coordinator, _, clock) = makeCoordinator(client: client)
        _ = await coordinator.synchronize(cause: .wake)

        clock.setNow(T.hours(1))
        await client.setRSS([
            remote("n1", hours: 0.1),
            remote("n2", hours: 0.2),
            remote("n3", hours: 0.3),
            remote("n4", hours: 0.4),
            remote("old", hours: -5)
        ])
        let report = await coordinator.synchronize(cause: .wake)
        #expect(report.notifications == [.summary(documentIds: ["n1", "n2", "n3", "n4"])])
    }
}

@Suite("Politica notifiche")
struct NotificationPolicyTests {
    @Test("sotto soglia restano avvisi singoli")
    func belowThresholdStaysIndividual() {
        let policy = NotificationPolicy(summaryThreshold: 4)
        #expect(
            policy.decisions(cause: .wake, newDocumentIds: ["a", "b", "c"])
                == [.newVox(documentId: "a"), .newVox(documentId: "b"), .newVox(documentId: "c")]
        )
    }

    @Test("la baseline non notifica neanche sopra soglia")
    func baselineNeverNotifies() {
        let policy = NotificationPolicy(summaryThreshold: 2)
        #expect(policy.decisions(cause: .firstLaunch, newDocumentIds: ["a", "b", "c"]).isEmpty)
    }
}
