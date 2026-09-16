import Foundation

public struct ChronocolConfiguration: Sendable, Equatable {
    public var baseURL: URL
    public var localePath: String
    public var listPageSize: Int
    public var maxJSONPages: Int
    public var jsonPageDelaySeconds: TimeInterval

    public init(
        baseURL: URL,
        localePath: String = "it",
        listPageSize: Int = 25,
        maxJSONPages: Int = 200,
        jsonPageDelaySeconds: TimeInterval = 0
    ) {
        self.baseURL = baseURL
        self.localePath = localePath
        self.listPageSize = listPageSize
        self.maxJSONPages = maxJSONPages
        self.jsonPageDelaySeconds = jsonPageDelaySeconds
    }

    public func permalink(documentId: String) -> URL {
        baseURL.appending(path: "\(localePath)/vox/\(documentId)")
    }

    public var rssURL: URL {
        baseURL.appending(path: "api/voxes/rss")
    }

    public func listURL(page: Int) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "api/voxes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "pagination[page]", value: String(page)),
            URLQueryItem(name: "pagination[pageSize]", value: String(listPageSize)),
            URLQueryItem(name: "sort", value: "createdAt:desc")
        ]
        return components.url!
    }

    public func detailURL(documentId: String) -> URL {
        baseURL.appending(path: "api/voxes/\(documentId)")
    }

    public var streamURL: URL {
        baseURL.appending(path: "api/voxes/stream")
    }
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public var session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

public enum ChronocolClientError: Error, Equatable {
    case incompatiblePayload(String)
    case httpStatus(Int)
}

public protocol ChronocolReading: Sendable {
    func fetchRSS() async throws -> [RemoteVox]
    func fetchListPage(page: Int) async throws -> VoxListPage
    func fetchDetail(documentId: String) async throws -> RemoteVox?
}

public struct ChronocolClient: ChronocolReading, Sendable {
    public var configuration: ChronocolConfiguration
    public var transport: any HTTPTransport

    public init(configuration: ChronocolConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetchRSS() async throws -> [RemoteVox] {
        let data = try await get(configuration.rssURL, expectedType: "xml")
        return try RSSParser.parse(data, permalinksFrom: configuration)
    }

    public func fetchListPage(page: Int) async throws -> VoxListPage {
        let data = try await get(configuration.listURL(page: page), expectedType: "json")
        return try ChronocolJSON.decodeList(data, configuration: configuration)
    }

    public func fetchDetail(documentId: String) async throws -> RemoteVox? {
        var request = URLRequest(url: configuration.detailURL(documentId: documentId))
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        let status = httpStatus(response)
        if status == 404 {
            return nil
        }
        try expectSuccess(status)
        return try ChronocolJSON.decodeDetail(data, configuration: configuration)
    }

    private func get(_ url: URL, expectedType: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try expectSuccess(httpStatus(response))
        _ = expectedType
        return data
    }

    private func httpStatus(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    private func expectSuccess(_ status: Int) throws {
        guard (200..<300).contains(status) else {
            throw ChronocolClientError.httpStatus(status)
        }
    }
}

enum ChronocolJSON {
    static func decodeList(_ data: Data, configuration: ChronocolConfiguration) throws -> VoxListPage {
        do {
            let envelope = try decoder.decode(ListEnvelope.self, from: data)
            return VoxListPage(
                items: envelope.data.map { $0.remote(configuration: configuration) },
                page: envelope.meta.pagination.page,
                pageSize: envelope.meta.pagination.pageSize,
                pageCount: envelope.meta.pagination.pageCount,
                total: envelope.meta.pagination.total
            )
        } catch let error as ChronocolClientError {
            throw error
        } catch {
            throw ChronocolClientError.incompatiblePayload(error.localizedDescription)
        }
    }

    static func decodeDetail(_ data: Data, configuration: ChronocolConfiguration) throws -> RemoteVox {
        do {
            let envelope = try decoder.decode(DetailEnvelope.self, from: data)
            return envelope.data.remote(configuration: configuration)
        } catch let error as ChronocolClientError {
            throw error
        } catch {
            throw ChronocolClientError.incompatiblePayload(error.localizedDescription)
        }
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { try ChronocolDates.decodeISO8601(from: $0) }
        return decoder
    }
}

/// Sottoinsieme minimo del JSON pubblico. Gli altri campi sono ignorati di proposito.
private struct ListEnvelope: Decodable {
    var data: [ItemDTO]
    var meta: MetaDTO
}

private struct DetailEnvelope: Decodable {
    var data: ItemDTO
}

private struct MetaDTO: Decodable {
    var pagination: PaginationDTO
}

private struct PaginationDTO: Decodable {
    var page: Int
    var pageSize: Int
    var pageCount: Int
    var total: Int
}

private struct ItemDTO: Decodable {
    var documentId: String
    var createdAt: Date
    var updatedAt: Date
    var listText: String

    enum CodingKeys: String, CodingKey {
        case documentId
        case createdAt
        case updatedAt
        case listText = "NOTIZIA"
    }

    func remote(configuration: ChronocolConfiguration) -> RemoteVox {
        RemoteVox(
            documentId: documentId,
            permalink: configuration.permalink(documentId: documentId),
            listText: listText,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
