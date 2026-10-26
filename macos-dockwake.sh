#!/bin/bash
#
# macos-dockwake
# Restarts the macOS Dock after wake or unlock to clear macOS 27 (Golden Gate)
# window-management glitches: clicks switching to the wrong app, the Dock and
# menu bar stuck over full-screen apps, and trackpad swipes between Spaces that
# stop working.
#
# The Dock process runs Mission Control, Spaces, full-screen app switching,
# Cmd-Tab and their gestures, and restarting it (killall Dock) clears the
# stuck state. This script installs a small background watcher that does that
# automatically a few seconds after the Mac wakes from sleep, the display
# wakes, or the screen is unlocked.
#
# Usage:
#   ./macos-dockwake.sh install     build and start the background watcher
#   ./macos-dockwake.sh reset       restart the Dock right now
#   ./macos-dockwake.sh status      show whether the watcher is running + recent log
#   ./macos-dockwake.sh uninstall   stop and remove everything this script installed
#
# Optional tuning at install time (seconds):
#   DELAY=3 COOLDOWN=30 ./macos-dockwake.sh install
#   DELAY    = wait after wake/unlock before restarting the Dock
#   COOLDOWN = minimum gap between automatic restarts (wake, display wake and
#              unlock often fire together; this collapses them into one restart)
#
# Requires Xcode Command Line Tools for the one-time build (xcode-select --install).
# Built and tested with Swift 6.4 on macOS 27.0.1.
#
# Project page: https://github.com/RosBradley/macos-dockwake

set -euo pipefail

LABEL="local.macos-dockwake"
SUPPORT_DIR="$HOME/Library/Application Support/macos-dockwake"
SRC="$SUPPORT_DIR/watcher.swift"
BIN="$SUPPORT_DIR/macos-dockwake-watcher"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/macos-dockwake.log"
DELAY="${DELAY:-3}"
COOLDOWN="${COOLDOWN:-30}"
DOMAIN="gui/$(id -u)"

# Earlier version of this tool, installed under the name spaces-fix.
LEGACY_LABEL="local.spaces-reset"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
LEGACY_DIR="$HOME/Library/Application Support/SpacesReset"
LEGACY_LOG="$HOME/Library/Logs/spaces-reset.log"

die() { echo "Error: $*" >&2; exit 1; }

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this script only runs on macOS."
}

is_number() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }

write_swift() {
  cat > "$SRC" <<'SWIFT'
import AppKit

// Line-buffer stdout so each log line reaches the log file immediately.
setvbuf(stdout, nil, _IOLBF, 0)

func log(_ message: String) {
    print("\(Date.now.formatted(.iso8601))  \(message)")
}

@MainActor
final class DockResetter {
    let delay: Double
    let cooldown: Double
    var lastTrigger = Date.distantPast

    // nonisolated: top-level code creates this object, and the init only sets stored properties.
    nonisolated init(delay: Double, cooldown: Double) {
        self.delay = delay
        self.cooldown = cooldown
    }

    func schedule(_ reason: String) {
        let since = Date.now.timeIntervalSince(lastTrigger)
        if since < cooldown {
            log("\(reason): skipped, Dock was reset \(Int(since))s ago")
            return
        }
        lastTrigger = Date.now
        log("\(reason): restarting Dock in \(Int(delay))s")
        let wait = delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            self.restartDock()
        }
    }

    func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        do {
            try task.run()
            task.waitUntilExit()
            log("Dock restarted (killall exit \(task.terminationStatus))")
        } catch {
            log("could not restart Dock: \(error.localizedDescription)")
        }
    }
}

let args = CommandLine.arguments
let delay = args.count > 1 ? (Double(args[1]) ?? 3) : 3
let cooldown = args.count > 2 ? (Double(args[2]) ?? 30) : 30
let resetter = DockResetter(delay: delay, cooldown: cooldown)

// No Dock icon, no menu bar; just a background listener.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let ws = NSWorkspace.shared.notificationCenter
ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { resetter.schedule("system wake") }
}
ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { resetter.schedule("display wake") }
}
// Undocumented system notification; if a future macOS stops sending it,
// the wake notifications above still trigger a reset.
DistributedNotificationCenter.default().addObserver(
    forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { resetter.schedule("screen unlock") }
}

log("watcher started (delay \(Int(delay))s, cooldown \(Int(cooldown))s)")
app.run()
SWIFT
}

write_plist() {
  cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
    <string>$DELAY</string>
    <string>$COOLDOWN</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
</dict>
</plist>
PLIST
}

unload_agent() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
}

remove_legacy() {
  if [[ -f "$LEGACY_PLIST" || -d "$LEGACY_DIR" ]]; then
    launchctl bootout "$DOMAIN/$LEGACY_LABEL" 2>/dev/null || true
    rm -f "$LEGACY_PLIST" "$LEGACY_LOG"
    rm -rf "$LEGACY_DIR"
    echo "Removed the earlier spaces-fix version."
  fi
}

cmd_install() {
  require_macos
  is_number "$DELAY" || die "DELAY must be a number of seconds."
  is_number "$COOLDOWN" || die "COOLDOWN must be a number of seconds."

  local swiftc
  swiftc="$(xcrun --find swiftc 2>/dev/null || command -v swiftc || true)"
  if [[ -z "$swiftc" ]]; then
    die "the Swift compiler wasn't found. Run: xcode-select --install
       then run this script again."
  fi

  mkdir -p "$SUPPORT_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

  echo "Building watcher..."
  write_swift
  # Swift 5 language mode avoids Swift 6's strictest concurrency checks.
  # Newer compilers still enforce some of them, which is why the watcher's
  # initializer is marked nonisolated.
  "$swiftc" -O -swift-version 5 "$SRC" -o "$BIN" \
    || die "build failed (see compiler output above)."

  echo "Installing launch agent..."
  remove_legacy
  write_plist
  plutil -lint "$PLIST" >/dev/null || die "generated plist is invalid: $PLIST"

  unload_agent
  sleep 1
  launchctl bootstrap "$DOMAIN" "$PLIST" \
    || die "launchctl could not load $PLIST"

  sleep 1
  echo
  echo "Installed. The Dock will restart ${DELAY}s after wake or unlock"
  echo "(at most once every ${COOLDOWN}s). It starts automatically at login."
  echo
  cmd_status
}

cmd_uninstall() {
  require_macos
  remove_legacy
  unload_agent
  rm -f "$PLIST"
  rm -rf "$SUPPORT_DIR"
  rm -f "$LOG"
  echo "Removed the watcher, its launch agent and its log."
}

cmd_status() {
  require_macos
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    local state pid
    state="$(launchctl print "$DOMAIN/$LABEL" | awk -F'= ' '/^[[:space:]]*state =/ {print $2; exit}')"
    pid="$(launchctl print "$DOMAIN/$LABEL" | awk -F'= ' '/^[[:space:]]*pid =/ {print $2; exit}')"
    echo "Watcher: loaded (state: ${state:-unknown}, pid: ${pid:-none})"
  else
    echo "Watcher: not installed"
  fi
  if [[ -f "$LOG" ]]; then
    echo "Recent log ($LOG):"
    tail -n 10 "$LOG" | sed 's/^/  /'
  fi
}

cmd_reset() {
  require_macos
  killall Dock && echo "Dock restarted."
}

case "${1:-}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  status)    cmd_status ;;
  reset)     cmd_reset ;;
  *)
    echo "Usage: $(basename "$0") install | reset | status | uninstall"
    echo "  install    build and start the automatic Dock reset on wake/unlock"
    echo "  reset      restart the Dock right now"
    echo "  status     show whether the watcher is running, with recent log lines"
    echo "  uninstall  remove everything this script installed"
    exit 1
    ;;
esac
