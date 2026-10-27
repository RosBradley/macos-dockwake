import Foundation

/// Restarts the Dock process, which also runs Mission Control, Spaces and
/// full-screen switching. macOS relaunches it at once.
@MainActor
final class DockResetter {
    private var lastTrigger = Date.distantPast

    /// After wake or unlock: wait a few seconds, and restart at most once per
    /// cooldown, since wake, display wake and unlock often arrive together.
    func schedule(_ reason: String) {
        let since = Date.now.timeIntervalSince(lastTrigger)
        if since < Settings.cooldown {
            log("\(reason): skipped, a Dock restart was already triggered \(Int(since))s ago")
            return
        }
        lastTrigger = Date.now
        let delay = Settings.delay
        Log.write("\(reason): restarting Dock in \(Int(delay))s")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            self.restartDock()
        }
    }

    /// Menu item or keyboard shortcut: restart right away, ignoring the
    /// delay and cooldown.
    func restartNow(_ reason: String) {
        Log.write("\(reason): restarting Dock now")
        restartDock()
    }

    private func log(_ message: String) { Log.write(message) }

    private func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        do {
            try task.run()
            task.waitUntilExit()
            Log.write("Dock restarted (killall exit \(task.terminationStatus))")
        } catch {
            Log.write("could not restart Dock: \(error.localizedDescription)")
        }
    }
}
