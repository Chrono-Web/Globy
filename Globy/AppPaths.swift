import Foundation

enum AppPaths {
    static var supportDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.chronocol.globy"
        return root.appendingPathComponent("Globy", isDirectory: true)
            .appendingPathComponent(bundle, isDirectory: true)
    }

    /// In Debug i dati veri (`--live`) stanno in un file a parte, per non mescolarli alla fixture.
    static func contentFile(live: Bool) -> URL {
        #if DEBUG
        supportDirectory.appendingPathComponent(live ? "content-live.json" : "content.json")
        #else
        supportDirectory.appendingPathComponent("content.json")
        #endif
    }
}
