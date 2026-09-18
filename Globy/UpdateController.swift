import AppKit
import Combine
import Sparkle

/// Aggiornamenti con Sparkle, senza le sue finestre: lo stato lo mostrano il pallino
/// sul globo, il menu, una notifica per versione e la sezione delle Impostazioni.
/// Il feed e la chiave pubblica stanno in `Info.plist` (docs/DISTRIBUZIONE.md).
@MainActor
final class UpdateController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        /// Trovata: aspetta «Scarica e installa». `downloaded` se è già sul disco.
        case available(downloaded: Bool)
        case downloading(progress: Double?)
        case extracting(progress: Double)
        case readyToRelaunch
        case installing
    }

    struct Release: Equatable {
        var version: String
        var notesURL: URL?
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var release: Release?
    /// Esito dell'ultimo controllo chiesto a mano: «aggiornato» o un errore.
    @Published private(set) var lastResult: String?
    @Published var automaticChecks: Bool {
        didSet { updater?.automaticallyChecksForUpdates = automaticChecks }
    }

    /// Sparkle chiede di mostrare l'aggiornamento in corso: si aprono le Impostazioni.
    var onShowPreferences: () -> Void = {}
    /// Avviso una volta per versione (Globy o notifica del Mac). Restituisce `false` se
    /// ora non si può dare, per esempio mentre Globy legge un VOX: si riprova più tardi.
    var onAnnounce: (String) -> Bool = { _ in true }

    private var updater: SPUUpdater?
    private var choiceReply: ((SPUUserUpdateChoice) -> Void)?
    private var relaunchReply: ((SPUUserUpdateChoice) -> Void)?
    private var cancelDownload: (() -> Void)?
    private var expectedLength: UInt64 = 0
    private var receivedLength: UInt64 = 0
    private let defaults: UserDefaults

    /// Pallino sul globo e riga nel menu.
    var hasUpdate: Bool {
        switch phase {
        case .available, .downloading, .extracting, .readyToRelaunch: true
        default: false
        }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        automaticChecks = true
        super.init()
    }

    func start() {
        // Nei test l'app ospita XCTest: niente rete né Sparkle.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
        do {
            try updater.start()
        } catch {
            lastResult = "Aggiornamenti non disponibili: \(error.localizedDescription)"
            return
        }
        self.updater = updater
        automaticChecks = updater.automaticallyChecksForUpdates
    }

    // MARK: Azioni

    func checkNow() {
        lastResult = nil
        updater?.checkForUpdates()
    }

    func install() {
        if let reply = relaunchReply {
            relaunchReply = nil
            phase = .installing
            reply(.install)
        } else if let reply = choiceReply {
            choiceReply = nil
            phase = .downloading(progress: nil)
            reply(.install)
        }
    }

    func cancel() {
        cancelDownload?()
        cancelDownload = nil
    }

    private func announceOnce(_ version: String) {
        guard defaults.string(forKey: Keys.announcedVersion) != version,
              case .available = phase, release?.version == version else { return }
        guard onAnnounce(version) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.announceOnce(version)
            }
            return
        }
        defaults.set(version, forKey: Keys.announcedVersion)
    }

    private enum Keys {
        static let announcedVersion = "updateAnnouncedVersion"
    }
}

// MARK: - SPUUserDriver

extension UpdateController: SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // `SUEnableAutomaticChecks` rende la domanda superflua; se arriva, sì e niente profilo.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        phase = .checking
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        let version = appcastItem.displayVersionString
        release = Release(version: version, notesURL: appcastItem.fullReleaseNotesURL ?? appcastItem.releaseNotesURL ?? appcastItem.infoURL)
        lastResult = nil
        if appcastItem.isInformationOnlyUpdate {
            // Nessun file da installare: resta la pagina della release.
            reply(.dismiss)
            phase = .idle
            lastResult = "È disponibile Globy \(version): scaricalo dalla pagina della release."
            return
        }
        if state.stage == .installing {
            // Già scaricato ed estratto in un avvio precedente: manca solo il riavvio.
            relaunchReply = reply
            phase = .readyToRelaunch
        } else {
            choiceReply = reply
            phase = .available(downloaded: state.stage == .downloaded)
        }
        if !state.userInitiated {
            announceOnce(version)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        phase = .idle
        lastResult = "Hai già l’ultima versione."
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        phase = .idle
        cancelDownload = nil
        lastResult = "Aggiornamento non riuscito: \(error.localizedDescription)"
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        cancelDownload = cancellation
        expectedLength = 0
        receivedLength = 0
        phase = .downloading(progress: nil)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedLength = expectedContentLength
        receivedLength = 0
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedLength += length
        guard expectedLength > 0 else { return }
        phase = .downloading(progress: min(Double(receivedLength) / Double(expectedLength), 1))
    }

    func showDownloadDidStartExtractingUpdate() {
        cancelDownload = nil
        phase = .extracting(progress: 0)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        phase = .extracting(progress: progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        relaunchReply = reply
        phase = .readyToRelaunch
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        phase = .installing
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        phase = .idle
        acknowledgement()
    }

    func showUpdateInFocus() {
        onShowPreferences()
    }

    func dismissUpdateInstallation() {
        // Fine della sessione di Sparkle: annullata, fallita o conclusa.
        choiceReply = nil
        relaunchReply = nil
        cancelDownload = nil
        phase = .idle
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateController: SPUUpdaterDelegate {
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        #if DEBUG
        // Prova locale: `--update-feed http://localhost:8000/appcast.xml`.
        let arguments = CommandLine.arguments
        if let i = arguments.firstIndex(of: "--update-feed"), i + 1 < arguments.count {
            return arguments[i + 1]
        }
        #endif
        return nil
    }
}
