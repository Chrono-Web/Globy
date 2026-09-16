import CryptoKit
import Foundation

/// VOX osservata localmente. `readAt` e `notifiedAt` sono fatti distinti.
public struct VoxRecord: Equatable, Sendable, Codable {
    public var documentId: String
    public var permalink: URL
    public var listText: String
    public var createdAt: Date
    public var updatedAt: Date
    public var fingerprint: String
    public var firstObservedAt: Date
    public var lastObservedAt: Date
    public var readAt: Date?
    public var notifiedAt: Date?
    public var isAvailable: Bool

    public init(
        documentId: String,
        permalink: URL,
        listText: String,
        createdAt: Date,
        updatedAt: Date,
        fingerprint: String,
        firstObservedAt: Date,
        lastObservedAt: Date,
        readAt: Date? = nil,
        notifiedAt: Date? = nil,
        isAvailable: Bool = true
    ) {
        self.documentId = documentId
        self.permalink = permalink
        self.listText = listText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fingerprint = fingerprint
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.readAt = readAt
        self.notifiedAt = notifiedAt
        self.isAvailable = isAvailable
    }
}

/// Payload minimo letto da RSS o JSON. Non è uno stato locale.
public struct RemoteVox: Equatable, Sendable {
    public var documentId: String
    public var permalink: URL
    public var listText: String
    public var createdAt: Date
    public var updatedAt: Date
    public var fingerprint: String

    public init(
        documentId: String,
        permalink: URL,
        listText: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.documentId = documentId
        self.permalink = permalink
        self.listText = listText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fingerprint = ContentFingerprint.make(updatedAt: updatedAt, listText: listText)
    }
}

public enum ContentFingerprint {
    public static func make(updatedAt: Date, listText: String) -> String {
        let digest = SHA256.hash(data: Data(listText.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(ChronocolDates.iso8601String(updatedAt))|\(hex)"
    }
}

public struct VoxListPage: Equatable, Sendable {
    public var items: [RemoteVox]
    public var page: Int
    public var pageSize: Int
    public var pageCount: Int
    public var total: Int

    public init(items: [RemoteVox], page: Int, pageSize: Int, pageCount: Int, total: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.pageCount = pageCount
        self.total = total
    }
}

public enum SyncCause: String, Sendable, Equatable {
    case firstLaunch
    case hint
    case reconnect
    case wake
    case polling
    case manual
}

public enum ContentChange: Equatable, Sendable {
    case published(documentId: String)
    case updated(documentId: String)
    case withdrawn(documentId: String)
}

public enum NotificationDecision: Equatable, Sendable {
    case newVox(documentId: String)
    case summary(documentIds: [String])
}

public struct SyncFailure: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case offline
        case incompatiblePayload
        case httpStatus(Int)
        case incompleteCatchUp
        case unknown
    }

    public var kind: Kind
    public var message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public struct SyncReport: Equatable, Sendable {
    public var cause: SyncCause
    public var completedBaseline: Bool
    public var usedRSS: Bool
    public var usedJSON: Bool
    public var jsonPagesFetched: Int
    public var changes: [ContentChange]
    public var notifications: [NotificationDecision]
    public var lastSuccessfulSyncAt: Date?
    public var failure: SyncFailure?
    public var coalesced: Bool
    public var streamFallback: Bool

    public init(
        cause: SyncCause,
        completedBaseline: Bool = false,
        usedRSS: Bool = false,
        usedJSON: Bool = false,
        jsonPagesFetched: Int = 0,
        changes: [ContentChange] = [],
        notifications: [NotificationDecision] = [],
        lastSuccessfulSyncAt: Date? = nil,
        failure: SyncFailure? = nil,
        coalesced: Bool = false,
        streamFallback: Bool = false
    ) {
        self.cause = cause
        self.completedBaseline = completedBaseline
        self.usedRSS = usedRSS
        self.usedJSON = usedJSON
        self.jsonPagesFetched = jsonPagesFetched
        self.changes = changes
        self.notifications = notifications
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.failure = failure
        self.coalesced = coalesced
        self.streamFallback = streamFallback
    }
}

/// Segnale non autorevole. Non implica che una VOX sia nuova.
public enum HintEvent: Equatable, Sendable {
    case connected
    case heartbeat
    case voxNew(documentId: String, createdAt: Date?)
    case voxUpdated(documentId: String)
    case malformed
    case unknown(event: String)
    case streamUnavailable(statusCode: Int)
}

public enum SyncHint: Equatable, Sendable {
    case none
    case voxNew(documentId: String)
    case voxUpdated(documentId: String)
    case streamUnavailable
    case wake
}
