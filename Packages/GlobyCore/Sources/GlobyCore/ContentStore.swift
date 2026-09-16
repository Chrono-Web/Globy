import Foundation

public struct StoreSnapshot: Equatable, Sendable, Codable {
    public var lastSuccessfulSyncAt: Date?
    public var hasCompletedBaseline: Bool
    public var records: [String: VoxRecord]

    public init(
        lastSuccessfulSyncAt: Date? = nil,
        hasCompletedBaseline: Bool = false,
        records: [String: VoxRecord] = [:]
    ) {
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.hasCompletedBaseline = hasCompletedBaseline
        self.records = records
    }
}

public struct StoreTransaction: Sendable {
    public var upserts: [VoxRecord]
    public var withdrawnIds: [String]
    public var lastSuccessfulSyncAt: Date?
    public var hasCompletedBaseline: Bool?

    public init(
        upserts: [VoxRecord] = [],
        withdrawnIds: [String] = [],
        lastSuccessfulSyncAt: Date? = nil,
        hasCompletedBaseline: Bool? = nil
    ) {
        self.upserts = upserts
        self.withdrawnIds = withdrawnIds
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.hasCompletedBaseline = hasCompletedBaseline
    }
}

public protocol ContentStore: Sendable {
    func snapshot() async -> StoreSnapshot
    func apply(_ transaction: StoreTransaction) async
    func markRead(documentId: String, at date: Date) async
}

public actor InMemoryContentStore: ContentStore {
    private var state = StoreSnapshot()

    public init() {}

    public func snapshot() -> StoreSnapshot {
        state
    }

    public func apply(_ transaction: StoreTransaction) {
        for record in transaction.upserts {
            state.records[record.documentId] = record
        }
        for id in transaction.withdrawnIds {
            if var record = state.records[id] {
                record.isAvailable = false
                state.records[id] = record
            }
        }
        if let cursor = transaction.lastSuccessfulSyncAt {
            state.lastSuccessfulSyncAt = cursor
        }
        if let baseline = transaction.hasCompletedBaseline {
            state.hasCompletedBaseline = baseline
        }
    }

    public func markRead(documentId: String, at date: Date) {
        guard var record = state.records[documentId] else { return }
        record.readAt = date
        state.records[documentId] = record
    }
}
