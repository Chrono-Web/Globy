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
