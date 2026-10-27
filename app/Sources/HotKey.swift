import Carbon.HIToolbox

/// Global keyboard shortcut Control+Option+Command+D. Carbon hot keys need no
/// Accessibility or Input Monitoring permission: macOS only tells the app when
/// its own key combination is pressed.
@MainActor
enum HotKey {
    static let description = "Control-Option-Command-D"
    private static var handler: (() -> Void)?
    private static var ref: EventHotKeyRef?
    private static var handlerInstalled = false

    /// Returns noErr on success; eventHotKeyExistsErr means another app holds
    /// the same combination.
    static func register(_ action: @escaping () -> Void) -> OSStatus {
        handler = action
        if !handlerInstalled {
            var spec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            // A C callback can't capture context, so it reaches the action
            // through the static property.
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { HotKey.handler?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        if ref != nil { return noErr }
        return RegisterEventHotKey(
            UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: OSType(0x444B_574B), id: 1),  // 'DKWK'
            GetApplicationEventTarget(), 0, &ref)
    }
}
