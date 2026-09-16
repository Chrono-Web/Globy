import Foundation

/// Persistenza JSON dietro `ContentStore`. Il file vive fuori dal bundle.
public actor FileContentStore: ContentStore {
    private let fileURL: URL
    private var state = StoreSnapshot()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(StoreSnapshot.self, from: data) {
            state = decoded
        }
    }

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
        persist()
    }

    public func markRead(documentId: String, at date: Date) {
        guard var record = state.records[documentId] else { return }
        record.readAt = date
        state.records[documentId] = record
        persist()
    }

    public func reset() {
        state = StoreSnapshot()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
