import Foundation

/// Persists the scratchpad between launches.
enum ScratchpadFile {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Mani/scratchpad.txt")
    }

    static func load() -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static func save(_ text: String) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
