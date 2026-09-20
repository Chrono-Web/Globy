import Combine
import Foundation

@MainActor
final class PreferenceStore: ObservableObject {
    private let defaults: UserDefaults

    /// Globy a schermo. Spento vuol dire modalità «notifiche di sistema»: i nuovi VOX
    /// arrivano come notifiche del Mac al posto del globo.
    @Published var mascotEnabled: Bool {
        didSet { defaults.set(mascotEnabled, forKey: Keys.mascotEnabled) }
    }

    @Published var permanence: Bool {
        didSet { defaults.set(permanence, forKey: Keys.permanence) }
    }

    /// Mostra il saluto di rientro dopo il risveglio del Mac o dello schermo.
    /// La sincronizzazione al risveglio resta attiva anche quando il saluto è spento.
    @Published var welcomesOnWake: Bool {
        didSet { defaults.set(welcomesOnWake, forKey: Keys.welcomesOnWake) }
    }

    @Published var mascotSoundEnabled: Bool {
        didSet { defaults.set(mascotSoundEnabled, forKey: Keys.mascotSound) }
    }

    /// Gli occhi del globo seguono il puntatore. Spento, il globo si ridisegna solo per
    /// battiti, saluti e lettura: meno lavoro per CPU e GPU mentre il mouse si muove.
    @Published var gazeFollowsPointer: Bool {
        didSet { defaults.set(gazeFollowsPointer, forKey: Keys.gazeFollowsPointer) }
    }

    /// Il saluto della mascotte è già comparso una volta.
    @Published var didGreet: Bool {
        didSet { defaults.set(didGreet, forKey: Keys.didGreet) }
    }

    /// La persona ha letto i due fatti e ha scelto sulle notifiche.
    @Published var didOnboard: Bool {
        didSet { defaults.set(didOnboard, forKey: Keys.didOnboard) }
    }

    /// Le scale restano salvate anche quando le dimensioni personalizzate sono spente.
    @Published var customSizesEnabled: Bool {
        didSet { defaults.set(customSizesEnabled, forKey: Keys.customSizes) }
    }

    @Published var textScale: Double {
        didSet { defaults.set(textScale, forKey: Keys.textScale) }
    }

    @Published var buttonScale: Double {
        didSet { defaults.set(buttonScale, forKey: Keys.buttonScale) }
    }

    @Published var globeScale: Double {
        didSet { defaults.set(globeScale, forKey: Keys.globeScale) }
    }

    /// Ultimo saluto di rientro, anche tra un avvio e l'altro: riavvii ravvicinati non
    /// devono ripetere «Heilà» se non c'è niente di nuovo.
    var lastWelcomeAt: Date? {
        get { defaults.object(forKey: Keys.lastWelcomeAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastWelcomeAt) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mascotEnabled = defaults.object(forKey: Keys.mascotEnabled) as? Bool ?? true
        permanence = defaults.bool(forKey: Keys.permanence)
        welcomesOnWake = defaults.object(forKey: Keys.welcomesOnWake) as? Bool ?? true
        mascotSoundEnabled = defaults.object(forKey: Keys.mascotSound) as? Bool ?? true
        gazeFollowsPointer = defaults.object(forKey: Keys.gazeFollowsPointer) as? Bool ?? true
        didGreet = defaults.bool(forKey: Keys.didGreet)
        didOnboard = defaults.bool(forKey: Keys.didOnboard)
        customSizesEnabled = defaults.bool(forKey: Keys.customSizes)
        textScale = defaults.object(forKey: Keys.textScale) as? Double ?? 1
        buttonScale = defaults.object(forKey: Keys.buttonScale) as? Double ?? 1
        globeScale = defaults.object(forKey: Keys.globeScale) as? Double ?? 1
    }

    func reset() {
        Keys.all.forEach { defaults.removeObject(forKey: $0) }
        mascotEnabled = true
        permanence = false
        welcomesOnWake = true
        mascotSoundEnabled = true
        gazeFollowsPointer = true
        didGreet = false
        didOnboard = false
        customSizesEnabled = false
        textScale = 1
        buttonScale = 1
        globeScale = 1
    }

    private enum Keys {
        static let mascotEnabled = "mascotEnabled"
        static let permanence = "permanence"
        static let welcomesOnWake = "welcomesOnWake"
        static let mascotSound = "mascotSoundEnabled"
        static let gazeFollowsPointer = "gazeFollowsPointer"
        static let didGreet = "didGreet"
        static let didOnboard = "didOnboard"
        static let customSizes = "customSizesEnabled"
        static let textScale = "textScale"
        static let buttonScale = "buttonScale"
        // Nuova chiave: la vecchia scala era relativa a un globo standard più grande.
        static let globeScale = "globySizeScale"
        static let lastWelcomeAt = "lastWelcomeAt"
        static let all = [mascotEnabled, permanence, welcomesOnWake, mascotSound, gazeFollowsPointer, didGreet, didOnboard,
                          customSizes, textScale, buttonScale, globeScale, lastWelcomeAt]
    }
}
