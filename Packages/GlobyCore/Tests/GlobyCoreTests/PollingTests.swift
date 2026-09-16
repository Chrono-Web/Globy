import Foundation
import Testing
import GlobyCore

@Suite("Polling")
struct PollingTests {
    @Test("senza errori l'attesa è l'intervallo base")
    func baseInterval() {
        let policy = PollingPolicy(interval: 300, maxInterval: 1800, jitterFraction: 0.1)
        #expect(policy.delay(consecutiveFailures: 0, random: 0) == 300)
    }

    @Test("gli errori raddoppiano l'attesa fino al tetto")
    func backoffIsCapped() {
        let policy = PollingPolicy(interval: 300, maxInterval: 1800, jitterFraction: 0)
        #expect(policy.delay(consecutiveFailures: 1, random: 0) == 600)
        #expect(policy.delay(consecutiveFailures: 2, random: 0) == 1200)
        #expect(policy.delay(consecutiveFailures: 3, random: 0) == 1800)
        #expect(policy.delay(consecutiveFailures: 50, random: 0) == 1800)
    }

    @Test("il jitter resta entro la frazione dichiarata")
    func jitterIsBounded() {
        let policy = PollingPolicy(interval: 300, maxInterval: 1800, jitterFraction: 0.1)
        #expect(policy.delay(consecutiveFailures: 0, random: -1) == 270)
        #expect(policy.delay(consecutiveFailures: 0, random: 1) == 330)
        #expect(policy.delay(consecutiveFailures: 0, random: 7) == 330)
    }
}
