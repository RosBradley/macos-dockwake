import AppKit

// Entry point. The app has no Dock icon (LSUIElement in Info.plist) and lives
// in the menu bar. Top-level code runs on the main thread, so it can create
// the main-actor app delegate directly.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    app.run()
}
