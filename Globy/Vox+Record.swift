import GlobyCore

extension Vox {
    init(record: VoxRecord, kind: Vox.Kind = .publication) {
        self.init(text: record.listText, permalink: record.permalink, kind: kind)
    }
}
