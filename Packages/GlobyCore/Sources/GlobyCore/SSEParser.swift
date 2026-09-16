import Foundation

public enum SSEParser {
    public static func parse(_ text: String) -> [HintEvent] {
        let blocks = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }

        return blocks.compactMap { parseBlock($0) }
    }

    public static func hint(from event: HintEvent) -> SyncHint? {
        switch event {
        case .voxNew(let documentId, _):
            return .voxNew(documentId: documentId)
        case .voxUpdated(let documentId):
            return .voxUpdated(documentId: documentId)
        case .streamUnavailable:
            return .streamUnavailable
        case .connected, .heartbeat, .malformed, .unknown:
            return nil
        }
    }

    private static func parseBlock(_ block: String) -> HintEvent? {
        var eventName: String?
        var dataLines: [String] = []
        var sawComment = false

        for rawLine in block.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(":") {
                sawComment = true
                continue
            }
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        let data = dataLines.joined(separator: "\n")
        if eventName == nil {
            return sawComment ? (block.contains("connected") ? .connected : .heartbeat) : nil
        }

        guard let eventName else { return nil }
        switch eventName {
        case "vox-new":
            return decodeNew(data)
        case "vox-updated":
            return decodeUpdated(data)
        default:
            return .unknown(event: eventName)
        }
    }

    private static func decodeNew(_ data: String) -> HintEvent {
        struct Payload: Decodable {
            var documentId: String
            var createdAt: String?
        }
        guard let body = data.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: body)
        else {
            return .malformed
        }
        let createdAt = payload.createdAt.flatMap(ChronocolDates.parseISO8601)
        return .voxNew(documentId: payload.documentId, createdAt: createdAt)
    }

    private static func decodeUpdated(_ data: String) -> HintEvent {
        struct Payload: Decodable {
            var documentId: String
        }
        guard let body = data.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: body)
        else {
            return .malformed
        }
        return .voxUpdated(documentId: payload.documentId)
    }
}
