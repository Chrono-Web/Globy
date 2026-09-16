import AppKit
import Foundation

/// Rilancia lo spike quando cambiano i sorgenti. Non è hot-reload in-process:
/// ricompila e riapre il globo col saluto.
enum LiveReload {
    static var isWatched: Bool { ProcessInfo.processInfo.environment["GLOBY_WATCH"] == "1" }

    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var scriptURL: URL { packageRoot.appendingPathComponent("watch") }

    static func startExternalWatch() throws {
        guard !isWatched else { return }
        let script = scriptURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "nohup \(shellEscape(script)) >/tmp/globy-mascot-watch.log 2>&1 &"]
        process.currentDirectoryURL = packageRoot
        try process.run()
        process.waitUntilExit()
    }

    static func stopExternalWatch() {
        let pidURL = URL(fileURLWithPath: "/tmp/globy-mascot-watch.pid")
        if let text = try? String(contentsOf: pidURL, encoding: .utf8),
           let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
        }
        try? FileManager.default.removeItem(at: pidURL)
    }

    private static func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
