import Foundation
import Testing
import GlobyCore

@Suite("Presentazione")
struct PresentationTests {
    @Test("il primo avvio non manda mascotte né banner")
    func firstLaunchIsSilent() {
        let report = SyncReport(
            cause: .firstLaunch,
            completedBaseline: true,
            changes: [.published(documentId: "a")],
            notifications: []
        )
        let plan = PresentationPolicy.plan(report: report, mascotEnabled: true, notificationsPaused: false)
        #expect(plan == .none)
    }

    @Test("mascotte spenta lascia i banner; pausa spegne i banner")
    func preferencesFilterPresentation() {
        let report = SyncReport(
            cause: .manual,
            notifications: [.newVox(documentId: "n1"), .newVox(documentId: "n2")]
        )
        let mascotOff = PresentationPolicy.plan(report: report, mascotEnabled: false, notificationsPaused: false)
        #expect(mascotOff.mascotDocumentIds.isEmpty)
        #expect(mascotOff.bannerDocumentIds == ["n1", "n2"])

        let paused = PresentationPolicy.plan(report: report, mascotEnabled: true, notificationsPaused: true)
        #expect(paused.mascotDocumentIds == ["n1", "n2"])
        #expect(paused.bannerDocumentIds.isEmpty)
    }

    @Test("un riepilogo tiene tutti gli id")
    func summaryKeepsAllIds() {
        let report = SyncReport(
            cause: .wake,
            notifications: [.summary(documentIds: ["a", "b", "c", "d"])]
        )
        let plan = PresentationPolicy.plan(report: report, mascotEnabled: true, notificationsPaused: false)
        #expect(plan.isSummary)
        #expect(plan.mascotDocumentIds == ["a", "b", "c", "d"])
        #expect(plan.bannerDocumentIds == ["a", "b", "c", "d"])
    }

    @Test("il saluto di rientro dice sempre com'è andata")
    func welcomeMessage() {
        #expect(WelcomePolicy.message(newVoxCount: 0, syncFailed: false).contains("Non ti sei perso nulla"))
        #expect(WelcomePolicy.message(newVoxCount: 1, syncFailed: false).contains("è uscito un nuovo VOX"))
        #expect(WelcomePolicy.message(newVoxCount: 3, syncFailed: false).contains("sono usciti 3 nuovi VOX"))
    }

    @Test("se la sincronizzazione fallisce il saluto non dice «nulla di nuovo»")
    func welcomeAfterFailureIsHonest() {
        let text = WelcomePolicy.message(newVoxCount: 0, syncFailed: true)
        #expect(!text.contains("Non ti sei perso nulla"))
        #expect(text.contains("non so ancora"))
    }

    @Test("il primo avvio propone i VOX recenti solo se ce ne sono")
    func introductionOffer() {
        #expect(WelcomePolicy.tourOffer(latestCount: 0) == nil)
        #expect(WelcomePolicy.tourOffer(latestCount: 1)?.hasSuffix("Partiamo con l'ultimo VOX pubblicato?") == true)
        #expect(WelcomePolicy.tourOffer(latestCount: 5)?.hasSuffix("Partiamo con gli ultimi 5 VOX pubblicati?") == true)
    }

    @Test("il fumetto resta quanto serve a leggerlo, entro i limiti")
    func lingerFollowsText() {
        #expect(ReadingPolicy.linger(forText: "Breve.") == ReadingPolicy.minimumLinger)
        let twenty = Array(repeating: "parola", count: 20).joined(separator: " ")
        #expect(abs(ReadingPolicy.linger(forText: twenty) - 6) < 0.001)
        let long = Array(repeating: "parola", count: 400).joined(separator: " ")
        #expect(ReadingPolicy.linger(forText: long) == ReadingPolicy.maximumLinger)
    }
}
