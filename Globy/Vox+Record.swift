import GlobyCore

extension Vox {
    init(record: VoxRecord, kind: Vox.Kind = .publication) {
        self.init(text: VoxText.readable(record.listText), permalink: record.permalink, kind: kind, documentId: record.documentId)
    }
}
