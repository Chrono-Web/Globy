import Foundation

public struct NotificationPolicy: Sendable, Equatable {
    public var summaryThreshold: Int

    public init(summaryThreshold: Int = 4) {
        self.summaryThreshold = summaryThreshold
    }

    public func decisions(cause: SyncCause, newDocumentIds: [String]) -> [NotificationDecision] {
        guard cause != .firstLaunch else { return [] }
        guard !newDocumentIds.isEmpty else { return [] }
        if newDocumentIds.count >= summaryThreshold {
            return [.summary(documentIds: newDocumentIds)]
        }
        return newDocumentIds.map { .newVox(documentId: $0) }
    }
}

public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var baseDelaySeconds: TimeInterval
    public var jitterFraction: Double

    public init(maxAttempts: Int = 3, baseDelaySeconds: TimeInterval = 0.2, jitterFraction: Double = 0.2) {
        self.maxAttempts = maxAttempts
        self.baseDelaySeconds = baseDelaySeconds
        self.jitterFraction = jitterFraction
    }

    public static let tests = RetryPolicy(maxAttempts: 3, baseDelaySeconds: 0.05, jitterFraction: 0)

    func delay(beforeAttempt attempt: Int) -> TimeInterval {
        guard attempt > 1 else { return 0 }
        let exponential = baseDelaySeconds * pow(2, Double(attempt - 2))
        guard jitterFraction > 0 else { return exponential }
        let jitter = exponential * jitterFraction * Double.random(in: -1...1)
        return max(0, exponential + jitter)
    }
}

/// Traduce le decisioni di sync in ciò che menu, mascotte e banner possono mostrare.
/// Le preferenze utente non cambiano lo store: filtrano solo la presentazione.
public struct PresentationPlan: Equatable, Sendable {
    public var mascotDocumentIds: [String]
    public var bannerDocumentIds: [String]
    public var isSummary: Bool

    public init(mascotDocumentIds: [String] = [], bannerDocumentIds: [String] = [], isSummary: Bool = false) {
        self.mascotDocumentIds = mascotDocumentIds
        self.bannerDocumentIds = bannerDocumentIds
        self.isSummary = isSummary
    }

    public static let none = PresentationPlan()
}

public enum PresentationPolicy {
    public static func plan(
        report: SyncReport,
        mascotEnabled: Bool,
        notificationsPaused: Bool
    ) -> PresentationPlan {
        var ids: [String] = []
        var isSummary = false
        for decision in report.notifications {
            switch decision {
            case .newVox(let documentId):
                ids.append(documentId)
            case .summary(let documentIds):
                ids.append(contentsOf: documentIds)
                isSummary = true
            }
        }
        guard !ids.isEmpty else { return .none }
        return PresentationPlan(
            mascotDocumentIds: mascotEnabled ? ids : [],
            bannerDocumentIds: notificationsPaused ? [] : ids,
            isSummary: isSummary
        )
    }
}

/// Saluto di rientro: all'avvio e al risveglio il globo dice sempre com'è andata.
/// Il numero viene dalla sincronizzazione appena conclusa, mai da un segnale SSE.
public enum WelcomePolicy {
    /// Onboarding raccontato dal globo dopo la presentazione: menu, Preferenze, notifiche.
    /// L'ultimo passo è una domanda: il permesso di sistema si chiede solo dopo il «Sì».
    public static let onboarding = [
        "Quando non ci sono io, mi trovi in alto nella barra dei menu: è il globo. Con un clic vedi gli ultimi VOX, e in evidenza quelli nuovi che non hai ancora letto.",
        "Nello stesso menu ci sono le Preferenze: puoi spegnermi, togliermi il suono, tenermi sempre a schermo o ingrandire testo e pulsanti.",
        "Ultima cosa: quando esce un nuovo VOX posso mandarti anche una notifica di sistema, senza suono. Le attivo?",
    ]

    /// Quanti VOX recenti il globo propone di mostrare al primo avvio.
    public static let tourSize = 5

    /// Primo fumetto del primo avvio: chi è Globy. Poi vengono i passi di `onboarding`.
    public static let introduction = "Ciao, sono Globy, la mascotte di Chronocol. Quando esce un nuovo VOX vengo un attimo qui, in basso a destra. Ti spiego in breve come funziono."

    /// Chiusura dell'onboarding: propone i VOX recenti. `nil` se non ce ne sono.
    public static func tourOffer(latestCount: Int) -> String? {
        switch latestCount {
        case ...0: nil
        case 1: "Tutto qui. Partiamo con l'ultimo VOX pubblicato?"
        default: "Tutto qui. Partiamo con gli ultimi \(latestCount) VOX pubblicati?"
        }
    }

    public static func message(newVoxCount: Int, syncFailed: Bool) -> String {
        if syncFailed {
            return "Heilà! Adesso non riesco a raggiungere Chronocol, quindi non so ancora se ti sei perso qualcosa. Io resto qui."
        }
        switch newVoxCount {
        case ...0:
            return "Heilà! Non ti sei perso nulla. Io resto attivo: se esce un nuovo VOX, arrivo."
        case 1:
            return "Heilà! Mentre eri via è uscito un nuovo VOX. Vuoi vederlo? Usa la freccia."
        default:
            return "Heilà! Mentre eri via sono usciti \(newVoxCount) nuovi VOX. Vuoi vederli? Usa la freccia."
        }
    }
}

/// Controllo HTTP periodico mentre il Mac è acceso. Valori provvisori finché la
/// frequenza non è concordata con Chronocol (`docs/CONTRATTO_API.md`, domanda 8):
/// una lettura ogni 5 minuti è lontanissima dal limite osservato di 180 al minuto.
public struct PollingPolicy: Sendable, Equatable {
    public var interval: TimeInterval
    public var maxInterval: TimeInterval
    public var jitterFraction: Double

    public init(interval: TimeInterval = 300, maxInterval: TimeInterval = 1800, jitterFraction: Double = 0.1) {
        self.interval = interval
        self.maxInterval = max(interval, maxInterval)
        self.jitterFraction = jitterFraction
    }

    /// Attesa prima del prossimo controllo. Gli errori consecutivi raddoppiano l'attesa
    /// fino a `maxInterval`; il jitter (`random` in -1...1) sparpaglia i client.
    public func delay(consecutiveFailures failures: Int, random: Double) -> TimeInterval {
        let exponent = min(max(failures, 0), 16)
        let base = min(interval * pow(2, Double(exponent)), maxInterval)
        let jitter = base * jitterFraction * min(max(random, -1), 1)
        return max(1, base + jitter)
    }
}

/// Quanto resta il fumetto dopo che il testo è stato scritto: il tempo di leggerlo,
/// a circa 200 parole al minuto, tra 2 e 15 secondi.
public enum ReadingPolicy {
    public static let minimumLinger: TimeInterval = 2
    public static let maximumLinger: TimeInterval = 15
    public static let secondsPerWord: TimeInterval = 0.3

    public static func linger(forText text: String) -> TimeInterval {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return min(maximumLinger, max(minimumLinger, Double(words) * secondsPerWord))
    }
}
