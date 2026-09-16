import Foundation
import os
import Testing
@testable import GlobyCore

@Suite("Contratto HTTP")
struct ContractDecodingTests {
    @Test("il decoder legge solo il sottoinsieme utile e ignora i campi extra")
    func decoderIgnoresUnknownFields() async throws {
        let client = ChronocolClient(
            configuration: testConfiguration(pageSize: 25),
            transport: StubTransport { request in
                httpOK(request, body: try fixtureData("list-page", ext: "json"))
            }
        )
        let page = try await client.fetchListPage(page: 1)
        #expect(page.items.count == 1)
        #expect(page.items[0].documentId == "fixture-vox-1")
        #expect(page.items[0].listText == "Testo sintetico della prima VOX di fixture.")
        #expect(page.pageCount == 3)
        #expect(page.items[0].permalink.absoluteString == "https://chronocol.test/it/vox/fixture-vox-1")
    }

    @Test("l'elenco JSON chiede sempre sort=createdAt:desc")
    func listRequestUsesRecencySort() async throws {
        let requested = OSAllocatedUnfairLock<URL?>(initialState: nil)
        let client = ChronocolClient(
            configuration: testConfiguration(),
            transport: StubTransport { request in
                requested.withLock { $0 = request.url }
                return httpOK(request, body: try fixtureData("list-page", ext: "json"))
            }
        )
        _ = try await client.fetchListPage(page: 2)
        let items = URLComponents(url: try #require(requested.withLock { $0 }), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "sort", value: "createdAt:desc")))
        #expect(items.contains(URLQueryItem(name: "pagination[page]", value: "2")))
        #expect(items.contains(URLQueryItem(name: "pagination[pageSize]", value: "2")))
    }

    @Test("un RSS di fixture copre il cursore e produce documentId dal permalink")
    func rssFixtureParsesDocumentIds() async throws {
        let client = ChronocolClient(
            configuration: testConfiguration(),
            transport: StubTransport { request in
                httpOK(request, body: try fixtureData("rss", ext: "xml"))
            }
        )
        let items = try await client.fetchRSS()
        #expect(items.map(\.documentId) == ["fixture-new", "fixture-old"])
        #expect(items[0].listText.contains("recente"))
    }

    @Test("un 404 sul dettaglio è un ritiro osservabile, non un payload incompatibile")
    func detail404IsWithdrawal() async throws {
        let client = ChronocolClient(
            configuration: testConfiguration(),
            transport: StubTransport { request in
                httpOK(request, body: Data(#"{"data":null}"#.utf8), status: 404)
            }
        )
        let detail = try await client.fetchDetail(documentId: "missing")
        #expect(detail == nil)
    }

    @Test("un JSON senza documentId è incompatibile")
    func missingDocumentIdIsIncompatible() async throws {
        let body = Data(#"{"data":[{"NOTIZIA":"x","createdAt":"2026-09-16T10:00:00.000Z","updatedAt":"2026-09-16T10:00:00.000Z"}],"meta":{"pagination":{"page":1,"pageSize":1,"pageCount":1,"total":1}}}"#.utf8)
        let client = ChronocolClient(
            configuration: testConfiguration(),
            transport: StubTransport { request in
                httpOK(request, body: body)
            }
        )
        await #expect(throws: ChronocolClientError.self) {
            _ = try await client.fetchListPage(page: 1)
        }
    }

    @Test("gli eventi SSE duplicati restano hint e non VOX")
    func sseFixtureIsOnlyAHint() throws {
        let text = try String(data: fixtureData("sse-vox-new", ext: "txt"), encoding: .utf8)
        let events = SSEParser.parse(try #require(text))
        #expect(events.first == .connected)
        #expect(events.filter { if case .voxNew = $0 { true } else { false } }.count == 2)
        #expect(SSEParser.hint(from: events[1]) == .voxNew(documentId: "fixture-new"))
    }
}
