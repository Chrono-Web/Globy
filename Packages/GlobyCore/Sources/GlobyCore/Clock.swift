import Foundation

/// Tempo iniettabile: backoff e cursori non devono dipendere dall'orologio di sistema nei test.
public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(seconds: TimeInterval) async throws
}

public struct SystemClock: Clock {
    public init() {}

    public var now: Date { Date() }

    public func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
