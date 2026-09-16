import Foundation
import os
import GlobyCore

enum T {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func hours(_ hours: Double) -> Date {
        t0.addingTimeInterval(hours * 3600)
    }
}

func remote(
    _ id: String,
    hours: Double,
    text: String? = nil,
    updatedHours: Double? = nil
) -> RemoteVox {
    RemoteVox(
        documentId: id,
        permalink: URL(string: "https://chronocol.test/it/vox/\(id)")!,
        listText: text ?? "testo \(id)",
        createdAt: T.hours(hours),
        updatedAt: T.hours(updatedHours ?? hours)
    )
}

func page(
    _ number: Int,
    of totalPages: Int,
    items: [RemoteVox],
    pageSize: Int = 2,
    total: Int = 4
) -> VoxListPage {
    VoxListPage(items: items, page: number, pageSize: pageSize, pageCount: totalPages, total: total)
}

final class ControllableClock: Clock, @unchecked Sendable {
    private struct State {
        var now: Date
        var sleeps: [TimeInterval] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(now: Date = T.t0) {
        state = OSAllocatedUnfairLock(initialState: State(now: now))
    }

    var now: Date {
        state.withLock(\.now)
    }

    var sleeps: [TimeInterval] {
        state.withLock(\.sleeps)
    }

    func setNow(_ date: Date) {
        state.withLock { $0.now = date }
    }

    func sleep(seconds: TimeInterval) async throws {
        state.withLock { $0.sleeps.append(seconds) }
    }
}

actor FakeChronocol: ChronocolReading {
    var rss: [RemoteVox] = []
    var pages: [Int: VoxListPage] = [:]
    var detailOverrides: [String: RemoteVox?] = [:]
    var rssFailuresRemaining = 0
    var rssError: Error = URLError(.notConnectedToInternet)
    var fetchRSSCount = 0
    var listPagesRequested: [Int] = []
    var detailsRequested: [String] = []

    private var holdFirstRSS = false
    private var fetchHasStarted = false
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var holdContinuation: CheckedContinuation<Void, Never>?

    func setRSS(_ items: [RemoteVox]) {
        rss = items
    }

    func setPages(_ pages: [Int: VoxListPage]) {
        self.pages = pages
    }

    func setDetail(_ id: String, _ value: RemoteVox?) {
        detailOverrides[id] = value
    }

    func failRSS(times: Int, error: Error = URLError(.notConnectedToInternet)) {
        rssFailuresRemaining = times
        rssError = error
    }

    func setHoldFirstRSS(_ value: Bool) {
        holdFirstRSS = value
    }

    func waitUntilRSSStarted() async {
        if fetchHasStarted { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func releaseRSS() {
        holdContinuation?.resume()
        holdContinuation = nil
    }

    func fetchRSS() async throws -> [RemoteVox] {
        fetchRSSCount += 1
        fetchHasStarted = true
        let waiters = startedWaiters
        startedWaiters = []
        waiters.forEach { $0.resume() }
        if holdFirstRSS, fetchRSSCount == 1 {
            await withCheckedContinuation { holdContinuation = $0 }
        }
        if rssFailuresRemaining > 0 {
            rssFailuresRemaining -= 1
            throw rssError
        }
        return rss
    }

    func fetchListPage(page: Int) async throws -> VoxListPage {
        listPagesRequested.append(page)
        guard let list = pages[page] else {
            throw ChronocolClientError.httpStatus(404)
        }
        return list
    }

    func fetchDetail(documentId: String) async throws -> RemoteVox? {
        detailsRequested.append(documentId)
        if let override = detailOverrides[documentId] {
            return override
        }
        if let found = rss.first(where: { $0.documentId == documentId }) {
            return found
        }
        for list in pages.values {
            if let found = list.items.first(where: { $0.documentId == documentId }) {
                return found
            }
        }
        return nil
    }
}

struct StubTransport: HTTPTransport {
    var handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

func httpOK(_ request: URLRequest, body: Data, status: Int = 200) -> (Data, URLResponse) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
    return (body, response)
}

func testConfiguration(pageSize: Int = 2, maxJSONPages: Int = 10) -> ChronocolConfiguration {
    ChronocolConfiguration(
        baseURL: URL(string: "https://chronocol.test")!,
        listPageSize: pageSize,
        maxJSONPages: maxJSONPages
    )
}

func makeCoordinator(
    client: FakeChronocol,
    store: InMemoryContentStore = InMemoryContentStore(),
    clock: ControllableClock = ControllableClock(),
    configuration: ChronocolConfiguration = testConfiguration(),
    policy: NotificationPolicy = NotificationPolicy(summaryThreshold: 4)
) -> (SyncCoordinator, InMemoryContentStore, ControllableClock) {
    let coordinator = SyncCoordinator(
        client: client,
        store: store,
        clock: clock,
        configuration: configuration,
        notificationPolicy: policy,
        retryPolicy: .tests
    )
    return (coordinator, store, clock)
}

func fixtureData(_ name: String, ext: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
    guard let url else {
        throw ChronocolClientError.incompatiblePayload("fixture mancante: \(name).\(ext)")
    }
    return try Data(contentsOf: url)
}
