import Foundation

/// Appends timestamped lines to ~/Library/Logs/macos-dockwake.log, the same
/// file the Terminal version writes, so Show Log opens it in Console.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/macos-dockwake.log")

    static func write(_ message: String) {
        let line = "\(Date.now.formatted(.iso8601))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }
}
