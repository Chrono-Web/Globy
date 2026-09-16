import Foundation

enum RSSParser {
    static func parse(_ data: Data, permalinksFrom configuration: ChronocolConfiguration) throws -> [RemoteVox] {
        let parser = FeedParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else {
            throw ChronocolClientError.incompatiblePayload("RSS non analizzabile")
        }
        return try parser.items.map { item in
            guard let identifier = item.documentId else {
                throw ChronocolClientError.incompatiblePayload("item RSS senza documentId")
            }
            guard let createdAt = item.pubDate.flatMap(ChronocolDates.parseRSS) else {
                throw ChronocolClientError.incompatiblePayload("item RSS senza pubDate")
            }
            let text = item.descriptionText ?? item.title ?? ""
            return RemoteVox(
                documentId: identifier,
                permalink: configuration.permalink(documentId: identifier),
                listText: text,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }
}

private final class FeedParser: NSObject, XMLParserDelegate {
    struct Item {
        var title: String?
        var link: String?
        var guid: String?
        var pubDate: String?
        var descriptionText: String?

        var documentId: String? {
            let raw = guid ?? link
            guard let raw, let url = URL(string: raw) else { return nil }
            let id = url.lastPathComponent
            return id.isEmpty ? nil : id
        }
    }

    var items: [Item] = []
    private var current: Item?
    private var buffer = ""
    private var inItem = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            inItem = true
            current = Item()
            buffer = ""
            return
        }
        if inItem {
            buffer = ""
        }
        _ = attributeDict
        _ = namespaceURI
        _ = qName
        _ = parser
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem {
            buffer += string
        }
        _ = parser
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer {
            buffer = ""
            _ = parser
            _ = namespaceURI
            _ = qName
        }
        guard inItem else { return }
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "item":
            if let current {
                items.append(current)
            }
            current = nil
            inItem = false
        case "title":
            current?.title = text
        case "link":
            current?.link = text
        case "guid":
            current?.guid = text
        case "pubDate":
            current?.pubDate = text
        case "description":
            current?.descriptionText = text
        default:
            break
        }
    }
}
