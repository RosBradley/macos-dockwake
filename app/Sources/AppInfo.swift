import Foundation

enum AppInfo {
    static let name = "macos-dockwake"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    /// Start at Login records the app's location, so it should live in an
    /// Applications folder rather than Downloads or a mounted disk image.
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }
}

/// Settings, stored with UserDefaults. Delay and cooldown have no menu items;
/// they can be changed with `defaults write io.github.rosbradley.macos-dockwake`.
enum Settings {
    static let restartAfterWakeKey = "RestartAfterWake"
    static let delayKey = "Delay"
    static let cooldownKey = "Cooldown"
    static let welcomedKey = "Welcomed"

    static var restartAfterWake: Bool {
        get { UserDefaults.standard.object(forKey: restartAfterWakeKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: restartAfterWakeKey) }
    }

    static var delay: Double {
        UserDefaults.standard.object(forKey: delayKey) as? Double ?? 3
    }

    static var cooldown: Double {
        UserDefaults.standard.object(forKey: cooldownKey) as? Double ?? 30
    }
}
