import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let resetter = DockResetter()
    private var statusItem: NSStatusItem?
    private var shortcutStatus: OSStatus = noErr

    private let restartItem = NSMenuItem(
        title: "Restart Dock Now", action: #selector(AppDelegate.restartFromMenu), keyEquivalent: "d")
    private let shortcutNoteItem = NSMenuItem(
        title: "Keyboard shortcut unavailable", action: nil, keyEquivalent: "")
    private let wakeItem = NSMenuItem(
        title: "Restart Dock After Wake or Unlock", action: #selector(AppDelegate.toggleWake),
        keyEquivalent: "")
    private let loginItem = NSMenuItem(
        title: "Start at Login", action: #selector(AppDelegate.toggleLogin), keyEquivalent: "")

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("app started (version \(AppInfo.version))")
        setUpMenu()
        if TerminalVersion.isInstalled {
            offerToRemoveTerminalVersion()
        }
        registerShortcut(retries: 3)
        observeWakeAndUnlock()
        if !UserDefaults.standard.bool(forKey: Settings.welcomedKey) {
            UserDefaults.standard.set(true, forKey: Settings.welcomedKey)
            showWelcome()
        }
    }

    /// Opening the app again while it runs shows where it is.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWelcome()
        return false
    }

    // MARK: - Menu

    private func setUpMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: AppInfo.name)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = AppInfo.name

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "\(AppInfo.name) \(AppInfo.version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        restartItem.keyEquivalentModifierMask = [.control, .option, .command]
        restartItem.target = self
        menu.addItem(restartItem)
        shortcutNoteItem.isEnabled = false
        shortcutNoteItem.isHidden = true
        menu.addItem(shortcutNoteItem)
        menu.addItem(.separator())

        wakeItem.target = self
        menu.addItem(wakeItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())

        addItem(to: menu, "Show Log", #selector(AppDelegate.showLog))
        addItem(to: menu, "About \(AppInfo.name)", #selector(AppDelegate.showAbout))
        addItem(to: menu, "Quit \(AppInfo.name)", #selector(AppDelegate.quit), key: "q")

        item.menu = menu
        statusItem = item
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    /// Refreshes check marks each time the menu opens; Start at Login can
    /// change in System Settings while the app runs.
    func menuNeedsUpdate(_ menu: NSMenu) {
        wakeItem.state = Settings.restartAfterWake ? .on : .off
        switch SMAppService.mainApp.status {
        case .enabled: loginItem.state = .on
        case .requiresApproval: loginItem.state = .mixed
        default: loginItem.state = .off
        }
        let shortcutWorks = shortcutStatus == noErr
        restartItem.keyEquivalent = shortcutWorks ? "d" : ""
        shortcutNoteItem.isHidden = shortcutWorks
    }

    // MARK: - Actions

    @objc private func restartFromMenu() {
        resetter.restartNow("menu")
    }

    @objc private func toggleWake() {
        Settings.restartAfterWake.toggle()
        Log.write("restart after wake or unlock turned \(Settings.restartAfterWake ? "on" : "off")")
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                Log.write("start at login turned off")
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                Log.write("start at login turned on")
            }
        } catch {
            Log.write("start at login change failed: \(error.localizedDescription)")
            showAlert(
                "Couldn't change Start at Login",
                "macOS said: \(error.localizedDescription)\n\nYou can add \(AppInfo.name) yourself in System Settings > General > Login Items & Extensions, with the + button under Open at Login.")
        }
    }

    @objc private func showLog() {
        if !FileManager.default.fileExists(atPath: Log.url.path) {
            Log.write("log opened")
        }
        NSWorkspace.shared.open(Log.url)
    }

    @objc private func showAbout() {
        bringToFront()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        Log.write("app quit")
        NSApp.terminate(nil)
    }

    // MARK: - Wake, unlock and the keyboard shortcut

    private func observeWakeAndUnlock() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.wakeEvent("system wake") }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.wakeEvent("display wake") }
        }
        // Undocumented system notification; if a future macOS stops sending
        // it, the wake notifications above still trigger a restart.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.wakeEvent("screen unlock") }
        }
    }

    private func wakeEvent(_ reason: String) {
        guard Settings.restartAfterWake else { return }
        resetter.schedule(reason)
    }

    /// Retries briefly: a Terminal version that was just removed may still be
    /// releasing the same shortcut.
    private func registerShortcut(retries: Int) {
        shortcutStatus = HotKey.register { [weak self] in
            self?.resetter.restartNow("keyboard shortcut")
        }
        if shortcutStatus == noErr {
            Log.write("keyboard shortcut \(HotKey.description) ready")
        } else if retries > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.registerShortcut(retries: retries - 1)
            }
        } else {
            Log.write("keyboard shortcut unavailable (error \(shortcutStatus)); another app may be using it")
        }
    }

    // MARK: - Alerts

    private func offerToRemoveTerminalVersion() {
        let alert = NSAlert()
        alert.messageText = "Remove the Terminal version of \(AppInfo.name)?"
        alert.informativeText = "The version installed with macos-dockwake.sh is also on this Mac. With both running, the Dock would restart twice after each wake, and the keyboard shortcut would only work in one of them. This app replaces it."
        alert.addButton(withTitle: "Remove It")
        alert.addButton(withTitle: "Keep Both")
        bringToFront()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if TerminalVersion.remove() {
            Log.write("removed the Terminal version")
        } else {
            showAlert(
                "Couldn't remove the Terminal version",
                "In Terminal, go to your macos-dockwake folder and run: ./macos-dockwake.sh uninstall")
        }
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = "\(AppInfo.name) is running"
        var text = "Its icon is in the menu bar at the top right of your screen.\n\nIt restarts the Dock a few seconds after your Mac wakes or unlocks, which clears the macOS 27 Dock, full-screen and Spaces glitches. Press \(HotKey.description) any time to restart the Dock right away."
        if !AppInfo.isInApplicationsFolder {
            text += "\n\nMove \(AppInfo.name) to your Applications folder before turning on Start at Login."
        }
        alert.informativeText = text
        let startsAtLogin = SMAppService.mainApp.status == .enabled
        if startsAtLogin {
            alert.addButton(withTitle: "OK")
        } else {
            alert.addButton(withTitle: "Start at Login")
            alert.addButton(withTitle: "Not Now")
        }
        bringToFront()
        let response = alert.runModal()
        if !startsAtLogin && response == .alertFirstButtonReturn {
            toggleLogin()
        }
    }

    private func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        bringToFront()
        alert.runModal()
    }

    private func bringToFront() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
