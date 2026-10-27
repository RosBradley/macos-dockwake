import Foundation

/// The LaunchAgent installed by macos-dockwake.sh. Running it next to the app
/// would restart the Dock twice and hold the keyboard shortcut.
enum TerminalVersion {
    private static let label = "local.macos-dockwake"
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let plist = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    private static let supportDir = home.appendingPathComponent(
        "Library/Application Support/macos-dockwake")

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plist.path)
    }

    /// Stops the watcher and removes its files. Keeps the shared log.
    static func remove() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        try? FileManager.default.removeItem(at: plist)
        try? FileManager.default.removeItem(at: supportDir)
        return !isInstalled
    }
}
