import Combine
import Foundation

@MainActor
final class PreferenceStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var mascotEnabled: Bool {
        didSet { defaults.set(mascotEnabled, forKey: Keys.mascotEnabled) }
    }

    @Published var permanence: Bool {
        didSet { defaults.set(permanence, forKey: Keys.permanence) }
    }

    @Published var mascotSoundEnabled: Bool {
        didSet { defaults.set(mascotSoundEnabled, forKey: Keys.mascotSound) }
    }

    @Published var notificationsPaused: Bool {
        didSet { defaults.set(notificationsPaused, forKey: Keys.notificationsPaused) }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mascotEnabled = defaults.object(forKey: Keys.mascotEnabled) as? Bool ?? true
        permanence = defaults.bool(forKey: Keys.permanence)
        mascotSoundEnabled = defaults.object(forKey: Keys.mascotSound) as? Bool ?? true
        notificationsPaused = defaults.bool(forKey: Keys.notificationsPaused)
        didGreet = defaults.bool(forKey: Keys.didGreet)
        didOnboard = defaults.bool(forKey: Keys.didOnboard)
        customSizesEnabled = defaults.bool(forKey: Keys.customSizes)
        textScale = defaults.object(forKey: Keys.textScale) as? Double ?? 1
        buttonScale = defaults.object(forKey: Keys.buttonScale) as? Double ?? 1
    }

    func reset() {
        Keys.all.forEach { defaults.removeObject(forKey: $0) }
        mascotEnabled = true
        permanence = false
        mascotSoundEnabled = true
        notificationsPaused = false
        didGreet = false
        didOnboard = false
        customSizesEnabled = false
        textScale = 1
        buttonScale = 1
    }

    private enum Keys {
        static let mascotEnabled = "mascotEnabled"
        static let permanence = "permanence"
        static let mascotSound = "mascotSoundEnabled"
        static let notificationsPaused = "notificationsPaused"
        static let didGreet = "didGreet"
        static let didOnboard = "didOnboard"
        static let customSizes = "customSizesEnabled"
        static let textScale = "textScale"
        static let buttonScale = "buttonScale"
        static let all = [mascotEnabled, permanence, mascotSound, notificationsPaused, didGreet, didOnboard,
                          customSizes, textScale, buttonScale]
    }
}
