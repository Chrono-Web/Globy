import Foundation

public actor SyncCoordinator {
    private let client: any ChronocolReading
    private let store: any ContentStore
    private let clock: any Clock
    private let notificationPolicy: NotificationPolicy
    private let retryPolicy: RetryPolicy
    private let configuration: ChronocolConfiguration
    private var inFlight: Task<SyncReport, Never>?

    public init(
        client: any ChronocolReading,
        store: any ContentStore,
        clock: any Clock,
        configuration: ChronocolConfiguration,
        notificationPolicy: NotificationPolicy = NotificationPolicy(),
        retryPolicy: RetryPolicy = .tests
    ) {
        self.client = client
        self.store = store
        self.clock = clock
        self.configuration = configuration
        self.notificationPolicy = notificationPolicy
        self.retryPolicy = retryPolicy
    }

    public func synchronize(cause: SyncCause, hint: SyncHint = .none) async -> SyncReport {
        if let inFlight {
            var report = await inFlight.value
            report.coalesced = true
            return report
        }
        let task = Task { [cause, hint] in
            await self.perform(cause: cause, hint: hint)
        }
        inFlight = task
        let report = await task.value
        inFlight = nil
        return report
    }

    public func handleHint(_ event: HintEvent) async -> SyncReport {
        switch event {
        case .voxNew(let documentId, _):
            return await synchronize(cause: .hint, hint: .voxNew(documentId: documentId))
        case .voxUpdated(let documentId):
            return await synchronize(cause: .hint, hint: .voxUpdated(documentId: documentId))
        case .streamUnavailable:
            var report = await synchronize(cause: .polling, hint: .streamUnavailable)
            report.streamFallback = true
            return report
        case .connected, .heartbeat, .malformed, .unknown:
            return SyncReport(cause: .hint)
        }
    }

    private func perform(cause: SyncCause, hint: SyncHint) async -> SyncReport {
        var lastError: SyncFailure?
        for attempt in 1...retryPolicy.maxAttempts {
            let delay = retryPolicy.delay(beforeAttempt: attempt)
            if delay > 0 {
                try? await clock.sleep(seconds: delay)
            }
            do {
                return try await runOnce(cause: cause, hint: hint)
            } catch {
                lastError = mapFailure(error)
                if !isRetryable(lastError) {
                    break
                }
            }
        }
        let snapshot = await store.snapshot()
        return SyncReport(
            cause: cause,
            completedBaseline: snapshot.hasCompletedBaseline,
            lastSuccessfulSyncAt: snapshot.lastSuccessfulSyncAt,
            failure: lastError
        )
    }

    private func runOnce(cause: SyncCause, hint: SyncHint) async throws -> SyncReport {
        let snapshot = await store.snapshot()
        let isBaseline = !snapshot.hasCompletedBaseline
        let effectiveCause = isBaseline ? SyncCause.firstLaunch : cause
        let startedAt = clock.now

        let rss = try await client.fetchRSS()
        var usedJSON = false
        var jsonPages = 0
        var remotes: [RemoteVox]

        if isBaseline {
            remotes = rss
        } else {
            let cursor = snapshot.lastSuccessfulSyncAt ?? startedAt
            if rssCoversHole(rss, cursor: cursor, store: snapshot) {
                remotes = rss
            } else {
                usedJSON = true
                let collected = try await collectJSONHole(cursor: cursor, jsonPages: &jsonPages)
                remotes = collected.items
                if !collected.covered {
                    return SyncReport(
                        cause: effectiveCause,
                        usedRSS: true,
                        usedJSON: true,
                        jsonPagesFetched: jsonPages,
                        failure: SyncFailure(kind: .incompleteCatchUp, message: "il JSON non ha coperto lastSuccessfulSyncAt"),
                        streamFallback: hint == .streamUnavailable
                    )
                }
            }
        }

        let hintRead = try await readHint(hint, knownIds: Set(snapshot.records.keys))
        remotes = merge(remotes: remotes, extras: hintRead.found)

        var changes: [ContentChange] = []
        var upserts: [VoxRecord] = []
        let withdrawnIds: [String] = hintRead.withdrawnIds
        var newDocumentIds: [String] = []
        var records = snapshot.records

        for remote in remotes {
            if var existing = records[remote.documentId] {
                let fingerprintChanged = existing.fingerprint != remote.fingerprint
                existing.permalink = remote.permalink
                existing.listText = remote.listText
                existing.createdAt = remote.createdAt
                existing.updatedAt = remote.updatedAt
                existing.fingerprint = remote.fingerprint
                existing.lastObservedAt = startedAt
                existing.isAvailable = true
                if fingerprintChanged {
                    changes.append(.updated(documentId: remote.documentId))
                }
                records[remote.documentId] = existing
                upserts.append(existing)
            } else {
                let record = VoxRecord(
                    documentId: remote.documentId,
                    permalink: remote.permalink,
                    listText: remote.listText,
                    createdAt: remote.createdAt,
                    updatedAt: remote.updatedAt,
                    fingerprint: remote.fingerprint,
                    firstObservedAt: startedAt,
                    lastObservedAt: startedAt
                )
                records[remote.documentId] = record
                upserts.append(record)
                changes.append(.published(documentId: remote.documentId))
                if !isBaseline {
                    newDocumentIds.append(remote.documentId)
                }
            }
        }

        for id in withdrawnIds {
            changes.append(.withdrawn(documentId: id))
            if var record = records[id] {
                record.isAvailable = false
                record.lastObservedAt = startedAt
                records[id] = record
            }
        }

        let notifications = notificationPolicy.decisions(
            cause: effectiveCause,
            newDocumentIds: newDocumentIds
        )
        let notifiedIds = notifiedDocumentIds(notifications)
        if !notifiedIds.isEmpty {
            upserts = upserts.map { record in
                guard notifiedIds.contains(record.documentId) else { return record }
                var updated = record
                updated.notifiedAt = startedAt
                records[updated.documentId] = updated
                return updated
            }
        }

        await store.apply(
            StoreTransaction(
                upserts: upserts,
                withdrawnIds: withdrawnIds,
                lastSuccessfulSyncAt: startedAt,
                hasCompletedBaseline: true
            )
        )

        return SyncReport(
            cause: effectiveCause,
            completedBaseline: true,
            usedRSS: true,
            usedJSON: usedJSON,
            jsonPagesFetched: jsonPages,
            changes: changes,
            notifications: notifications,
            lastSuccessfulSyncAt: startedAt,
            streamFallback: hint == .streamUnavailable
        )
    }

    private func rssCoversHole(_ rss: [RemoteVox], cursor: Date, store: StoreSnapshot) -> Bool {
        guard let oldest = rss.map(\.createdAt).min() else { return false }
        if oldest <= cursor { return true }
        return rss.contains { store.records[$0.documentId] != nil }
    }

    private func collectJSONHole(cursor: Date, jsonPages: inout Int) async throws -> (items: [RemoteVox], covered: Bool) {
        var collected: [RemoteVox] = []
        var covered = false
        var page = 1
        while !covered, jsonPages < configuration.maxJSONPages {
            if jsonPages > 0, configuration.jsonPageDelaySeconds > 0 {
                try await clock.sleep(seconds: configuration.jsonPageDelaySeconds)
            }
            let list = try await client.fetchListPage(page: page)
            jsonPages += 1
            for item in list.items {
                if item.createdAt > cursor {
                    collected.append(item)
                } else {
                    covered = true
                }
            }
            if list.items.isEmpty || page >= list.pageCount {
                covered = true
            }
            page += 1
        }
        return (dedupe(collected), covered)
    }

    private func readHint(_ hint: SyncHint, knownIds: Set<String>) async throws -> (found: [RemoteVox], withdrawnIds: [String]) {
        let documentId: String
        switch hint {
        case .voxNew(let id), .voxUpdated(let id):
            documentId = id
        case .none, .streamUnavailable, .wake:
            return ([], [])
        }
        if let remote = try await client.fetchDetail(documentId: documentId) {
            return ([remote], [])
        }
        if knownIds.contains(documentId) {
            return ([], [documentId])
        }
        return ([], [])
    }

    private func merge(remotes: [RemoteVox], extras: [RemoteVox]) -> [RemoteVox] {
        var seen = Set(remotes.map(\.documentId))
        var result = remotes
        for extra in extras where !seen.contains(extra.documentId) {
            seen.insert(extra.documentId)
            result.append(extra)
        }
        for extra in extras {
            if let index = result.firstIndex(where: { $0.documentId == extra.documentId }) {
                result[index] = extra
            }
        }
        return result
    }

    private func dedupe(_ remotes: [RemoteVox]) -> [RemoteVox] {
        var seen = Set<String>()
        var result: [RemoteVox] = []
        for remote in remotes where seen.insert(remote.documentId).inserted {
            result.append(remote)
        }
        return result
    }

    private func notifiedDocumentIds(_ decisions: [NotificationDecision]) -> Set<String> {
        var ids = Set<String>()
        for decision in decisions {
            switch decision {
            case .newVox(let documentId):
                ids.insert(documentId)
            case .summary(let documentIds):
                ids.formUnion(documentIds)
            }
        }
        return ids
    }

    private func isRetryable(_ failure: SyncFailure?) -> Bool {
        switch failure?.kind {
        case .offline, .unknown:
            return true
        case .httpStatus(let status):
            return status == 429 || (500..<600).contains(status)
        case .incompatiblePayload, .incompleteCatchUp, .none:
            return false
        }
    }

    private func mapFailure(_ error: Error) -> SyncFailure {
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return SyncFailure(kind: .offline, message: url.localizedDescription)
            default:
                return SyncFailure(kind: .unknown, message: url.localizedDescription)
            }
        }
        if let client = error as? ChronocolClientError {
            switch client {
            case .incompatiblePayload(let message):
                return SyncFailure(kind: .incompatiblePayload, message: message)
            case .httpStatus(let status):
                if status == 503 || (500..<600).contains(status) {
                    return SyncFailure(kind: .httpStatus(status), message: "HTTP \(status)")
                }
                return SyncFailure(kind: .httpStatus(status), message: "HTTP \(status)")
            }
        }
        return SyncFailure(kind: .unknown, message: String(describing: error))
    }
}
