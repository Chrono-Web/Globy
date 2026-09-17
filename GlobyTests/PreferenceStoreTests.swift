import Foundation
import Testing
@testable import Globy

@Suite("Preferenze")
struct PreferenceStoreTests {
    @Test("azzera riporta saluto e onboarding al primo avvio")
    @MainActor
    func resetClearsFirstLaunchFlags() {
        let suite = "globy.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = PreferenceStore(defaults: defaults)
        store.didGreet = true
        store.didOnboard = true
        store.permanence = true
        store.gazeFollowsPointer = false
        store.reset()
        #expect(!store.didGreet)
        #expect(!store.didOnboard)
        #expect(!store.permanence)
        #expect(store.mascotEnabled)
        #expect(store.gazeFollowsPointer)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("spegnere le dimensioni personalizzate conserva i valori")
    @MainActor
    func customSizesSurviveToggle() {
        let suite = "globy.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = PreferenceStore(defaults: defaults)
        store.customSizesEnabled = true
        store.textScale = 1.3
        store.buttonScale = 1.5
        store.customSizesEnabled = false
        let reloaded = PreferenceStore(defaults: defaults)
        #expect(!reloaded.customSizesEnabled)
        #expect(reloaded.textScale == 1.3)
        #expect(reloaded.buttonScale == 1.5)
        defaults.removePersistentDomain(forName: suite)
    }
}
