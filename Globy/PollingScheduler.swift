import Foundation
import GlobyCore

/// Un solo timer alla volta, ripianificato dopo ogni sincronizzazione qualunque ne sia
/// la causa. Fermo durante lo stop del Mac: al risveglio ci pensa la sync di rientro.
@MainActor
final class PollingScheduler {
    private let policy: PollingPolicy
    private let onFire: () -> Void
    private var timer: Timer?
    private var failures = 0
    private var paused = true

    init(policy: PollingPolicy, onFire: @escaping () -> Void) {
        self.policy = policy
        self.onFire = onFire
    }

    /// Esito dell'ultima sincronizzazione: azzera o allunga l'attesa e riparte.
    func record(success: Bool) {
        failures = success ? 0 : failures + 1
        paused = false
        reschedule()
    }

    func pause() {
        paused = true
        timer?.invalidate()
        timer = nil
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard !paused else { return }
        let delay = policy.delay(consecutiveFailures: failures, random: .random(in: -1...1))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.onFire() }
        }
        // Margine ampio: il sistema può accorpare il risveglio con altri timer.
        timer.tolerance = delay * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
