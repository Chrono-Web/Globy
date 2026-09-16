import AppKit
import Combine
import Foundation
import GlobyCore
import Network

/// Proprietario unico della sessione: sync, store, menu, mascotte e banner.
@MainActor
final class AppSession: ObservableObject {
    let preferences: PreferenceStore
    let notifications = NotificationCoordinator()
    let mascot = MascotWindowController()

    @Published private(set) var records: [VoxRecord] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastFailure: String?
    @Published var launchAtLogin: Bool
    @Published var notificationStatusNote: String?

    private let store: FileContentStore
    /// Solo in Debug senza `--live`: Chronocol finto in processo, per simulare pubblicazioni.
    private let fixture: FixtureChronocol?

    var usesFixture: Bool { fixture != nil }
    private let coordinator: SyncCoordinator
    private var cancellables: [AnyCancellable] = []
    private var started = false
    private var lastWelcomeAt: Date?
    private var poller: PollingScheduler?
    private let pathMonitor = NWPathMonitor()
    private var networkWasOffline = false

    var unreadCount: Int {
        records.filter { $0.isAvailable && isUnread($0) }.count
    }

    /// Non letto = arrivato dopo la baseline e mai aperto. L'archivio trovato al primo
    /// avvio non è una novità: non conta tra i non letti (come non viene notificato).
    func isUnread(_ record: VoxRecord) -> Bool {
        guard record.readAt == nil, let baselineAt else { return false }
        return record.firstObservedAt > baselineAt
    }

    /// Momento della baseline: la prima osservazione più vecchia nello store.
    private var baselineAt: Date? {
        records.map(\.firstObservedAt).min()
    }

    var recent: [VoxRecord] {
        records
            .filter(\.isAvailable)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(15)
            .map { $0 }
    }

    static var readsLiveChronocol: Bool {
        #if DEBUG
        CommandLine.arguments.contains("--live")
        #else
        true
        #endif
    }

    init(preferences: PreferenceStore = PreferenceStore()) {
        self.preferences = preferences
        launchAtLogin = LoginItem.isEnabled
        let configuration = ChronocolConfiguration(baseURL: URL(string: "https://chronocol.com")!)
        let client: any ChronocolReading
        // Release legge Chronocol pubblico (solo GET). Debug usa la fixture, salvo `--live`.
        if AppSession.readsLiveChronocol {
            fixture = nil
            client = ChronocolClient(configuration: configuration, transport: URLSessionTransport())
        } else {
            let fake = FixtureChronocol()
            fixture = fake
            client = fake
        }
        store = FileContentStore(fileURL: AppPaths.contentFile(live: fixture == nil))
        coordinator = SyncCoordinator(
            client: client,
            store: store,
            clock: SystemClock(),
            configuration: configuration,
            retryPolicy: RetryPolicy(maxAttempts: 3, baseDelaySeconds: 0.4, jitterFraction: 0.2)
        )
        mascot.surface = .systemDefault
        mascot.soundEnabled = preferences.mascotSoundEnabled
        mascot.permanence = preferences.permanence

        preferences.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        preferences.$mascotEnabled.sink { [weak self] enabled in
            guard let self else { return }
            if !enabled { self.mascot.dismissAll() }
        }.store(in: &cancellables)
        preferences.$permanence.sink { [weak self] value in
            self?.mascot.permanence = value
        }.store(in: &cancellables)
        preferences.$mascotSoundEnabled.sink { [weak self] value in
            self?.mascot.soundEnabled = value
        }.store(in: &cancellables)
        Publishers.CombineLatest3(preferences.$customSizesEnabled, preferences.$textScale, preferences.$buttonScale)
            .sink { [weak self] custom, text, buttons in
                MascotMetrics.textScale = custom ? text : 1
                MascotMetrics.buttonScale = custom ? buttons : 1
                self?.mascot.metricsDidChange()
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !started else { return }
        started = true
        // Risveglio del Mac o dello schermo: sincronizza e saluta. I due avvisi arrivano
        // spesso insieme, `presentWelcome` ne tiene uno solo.
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    // Qualche secondo per lasciar tornare la rete.
                    try? await Task.sleep(for: .seconds(3))
                    await self?.synchronize(cause: .wake, welcome: true)
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.poller?.pause() }
        }
        startPolling()
        startNetworkMonitor()
        // Al primissimo avvio c'è il saluto di presentazione; dopo, quello di rientro.
        if preferences.didGreet {
            Task { await synchronize(cause: .wake, welcome: true) }
        } else {
            // La presentazione aspetta la baseline: serve sapere quali VOX proporre.
            Task {
                await synchronize(cause: .wake)
                presentGreetingIfNeeded()
            }
        }
    }

    func synchronize(cause: SyncCause, welcome: Bool = false) async {
        isSyncing = true
        let report = await coordinator.synchronize(cause: cause)
        isSyncing = false
        // Una sync accorpata a quella in volo ne riporta lo stesso esito: già presentato.
        guard !report.coalesced else { return }
        poller?.record(success: report.failure == nil)
        lastFailure = report.failure.map(\.message)
        await refreshRecords()
        present(report, welcome: welcome)
    }

    func open(_ record: VoxRecord) {
        Task {
            await store.markRead(documentId: record.documentId, at: Date())
            await refreshRecords()
        }
        NSApp.activate(ignoringOtherApps: true)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(record.permalink, configuration: configuration) { _, error in
            if let error {
                Task { @MainActor in
                    self.lastFailure = error.localizedDescription
                }
            }
        }
    }

    func finishOnboarding(requestNotifications: Bool) async {
        preferences.didOnboard = true
        if requestNotifications {
            let status = await notifications.requestAfterExplanation()
            notificationStatusNote = status == .denied
                ? "Permesso negato. Puoi cambiarlo in Impostazioni di sistema › Notifiche."
                : nil
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.setEnabled(on)
            launchAtLogin = LoginItem.isEnabled
        } catch {
            launchAtLogin = LoginItem.isEnabled
            lastFailure = error.localizedDescription
        }
    }

    func resetLocalData() async {
        mascot.dismissAll()
        await store.reset()
        preferences.reset()
        launchAtLogin = LoginItem.isEnabled
        notificationStatusNote = nil
        await synchronize(cause: .wake)
        presentGreetingIfNeeded()
    }

    func simulatePublication() async {
        let now = Date()
        guard let fixture else { return }
        await fixture.publish(
            RemoteVox(
                documentId: "fixture-new-\(UUID().uuidString)",
                permalink: URL(string: "https://chronocol.com/it")!,
                listText: "Nuovo VOX simulato. Il globo compare solo dopo questa conferma locale.",
                createdAt: now,
                updatedAt: now
            )
        )
        await synchronize(cause: .manual)
    }

    func simulateBurst() async {
        let now = Date()
        guard let fixture else { return }
        for index in 0..<3 {
            await fixture.publish(
                RemoteVox(
                    documentId: "fixture-burst-\(UUID().uuidString)",
                    permalink: URL(string: "https://chronocol.com/it")!,
                    listText: "VOX di raffica \(index + 1) (fixture locale).",
                    createdAt: now.addingTimeInterval(TimeInterval(index)),
                    updatedAt: now.addingTimeInterval(TimeInterval(index))
                )
            )
        }
        await synchronize(cause: .manual)
    }

    private func refreshRecords() async {
        let snapshot = await store.snapshot()
        records = Array(snapshot.records.values)
    }

    private func startPolling(policy: PollingPolicy = PollingPolicy()) {
        var policy = policy
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "--poll-seconds"),
           i + 1 < CommandLine.arguments.count, let seconds = TimeInterval(CommandLine.arguments[i + 1]) {
            policy = PollingPolicy(interval: seconds, maxInterval: seconds * 6)
        }
        #endif
        poller = PollingScheduler(policy: policy) { [weak self] in
            Task { await self?.synchronize(cause: .polling) }
        }
    }

    /// Al ritorno della rete controlla subito, senza aspettare il prossimo giro.
    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                defer { self.networkWasOffline = !online }
                guard online, self.networkWasOffline else { return }
                await self.synchronize(cause: .reconnect)
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "globy.network"))
    }

    private func presentWelcome(report: SyncReport, records: [VoxRecord]) {
        let now = Date()
        if let lastWelcomeAt, now.timeIntervalSince(lastWelcomeAt) < 60, records.isEmpty { return }
        lastWelcomeAt = now
        let text = WelcomePolicy.message(newVoxCount: records.count, syncFailed: report.failure != nil)
        mascot.presentGreeting(.welcome(text), then: records.map { Vox(record: $0) })
    }

    #if DEBUG
    /// Pubblica sulla fixture senza sincronizzare: lo scopre il prossimo controllo periodico.
    func publishWithoutSync() async {
        let now = Date()
        guard let fixture else { return }
        await fixture.publish(
            RemoteVox(
                documentId: "fixture-poll-\(UUID().uuidString)",
                permalink: URL(string: "https://chronocol.com/it")!,
                listText: "VOX scoperto dal controllo periodico (fixture locale).",
                createdAt: now,
                updatedAt: now
            )
        )
    }

    /// Simula un rientro con `count` VOX usciti mentre il Mac dormiva.
    func simulateReturn(newVoxCount count: Int) async {
        let now = Date()
        guard let fixture else { return }
        for index in 0..<count {
            await fixture.publish(
                RemoteVox(
                    documentId: "fixture-away-\(UUID().uuidString)",
                    permalink: URL(string: "https://chronocol.com/it")!,
                    listText: "VOX uscito mentre eri via \(index + 1) (fixture locale).",
                    createdAt: now.addingTimeInterval(TimeInterval(index)),
                    updatedAt: now.addingTimeInterval(TimeInterval(index))
                )
            )
        }
        await synchronize(cause: .wake, welcome: true)
    }
    #endif

    private func presentGreetingIfNeeded() {
        guard preferences.mascotEnabled, !preferences.didGreet else { return }
        preferences.didGreet = true
        // Su richiesta, gli ultimi VOX già usciti: presentati come «recenti», mai notificati.
        let latest = recent.prefix(WelcomePolicy.tourSize).map { Vox(record: $0, kind: .recent) }
        let greeting = Vox.welcome(WelcomePolicy.introduction(latestCount: latest.count), asksChoice: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.mascot.presentGreeting(greeting, then: latest)
        }
    }

    private func present(_ report: SyncReport, welcome: Bool) {
        let plan = PresentationPolicy.plan(
            report: report,
            mascotEnabled: preferences.mascotEnabled,
            notificationsPaused: preferences.notificationsPaused
        )
        let mascotRecords = plan.mascotDocumentIds.compactMap { id in records.first { $0.documentId == id } }
        if welcome, report.cause != .firstLaunch, preferences.mascotEnabled {
            presentWelcome(report: report, records: mascotRecords)
        } else if !mascotRecords.isEmpty {
            mascot.summonBurst(mascotRecords.map { Vox(record: $0) })
        }
        guard !plan.bannerDocumentIds.isEmpty else { return }
        if plan.isSummary {
            notifications.post(
                title: "Nuovi VOX su Chronocol",
                body: "Ci sono \(plan.bannerDocumentIds.count) nuovi VOX.",
                permalink: URL(string: "https://chronocol.com/it")!,
                documentId: "summary"
            )
        } else {
            for id in plan.bannerDocumentIds {
                guard let record = records.first(where: { $0.documentId == id }) else { continue }
                notifications.post(
                    title: "Nuovo VOX",
                    body: VoxText.readable(record.listText),
                    permalink: record.permalink,
                    documentId: record.documentId
                )
            }
        }
    }
}
