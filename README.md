# macos-dockwake

Restarts the macOS Dock automatically after your Mac wakes or unlocks, to clear window-management glitches in macOS 27 (Golden Gate).

## The problem

On macOS 27.0.1, the Dock, Mission Control and Spaces can get into a stuck state. The symptoms are:

- **Clicking an open app in the Dock switches to a different app.** A second click usually goes to the right one.
- **Full-screen apps keep the Dock and menu bar drawn over them.** This was seen with Outlook, but any full-screen app can be affected.
- **Three-finger swipes between Spaces stop working**, sometimes only for a while.

This is a known macOS 27 bug, not something wrong with your Mac. As of October 26, 2026:

- macOS 27.0.1 does not fix it.
- There is no macOS 27.1 for Macs.
- macOS 27.2, released October 26, doesn't mention a fix. Its notes cover Siri, Messages and security fixes, and nothing about the Dock, Mission Control, Spaces or full screen.
- Testers reported the bug was still present in the 27.2 betas, and no one has reported it fixed in the final release.

## Why restarting the Dock helps

The Dock process does much more than show the Dock. It also runs Mission Control, Spaces, full-screen app switching, Cmd-Tab and their trackpad gestures. Restarting it with `killall Dock` clears the stuck state. macOS relaunches the Dock right away, and your apps and windows are not affected.

The glitches tend to show up after sleep or unlock. macOS gives no signal when the stuck state starts, so this tool restarts the Dock each time you come back to the Mac.

## How it works

`macos-dockwake.sh install` sets up a small background watcher:

1. It writes a short Swift program and compiles it on your Mac.
2. It installs a LaunchAgent, `local.macos-dockwake`, which starts the watcher at login and restarts it if it ever quits.
3. The watcher listens for three events: the system waking, the display waking and the screen unlocking.
4. A few seconds after any of them, it runs `killall Dock` and writes a line to its log.

These events often fire together, so a cooldown makes sure the Dock restarts only once per wake.

The watcher has no Dock icon or menu bar item. It uses almost no CPU or memory, since it just waits for events.

## Requirements

- macOS 27. It also runs on macOS 13 or later, but those versions don't have this bug.
- Xcode Command Line Tools, for the one-time build. Install them with `xcode-select --install` if you don't have Xcode.

## Install

```sh
git clone https://github.com/RosBradley/macos-dockwake.git
cd macos-dockwake
./macos-dockwake.sh install
```

To confirm it's working, sleep and wake your Mac, then run:

```sh
./macos-dockwake.sh status
```

The log should show a line such as `system wake: restarting Dock in 3s`, followed by `Dock restarted`.

### Settings

You can change two timings when you install:

| Setting | Default | What it does |
|---|---|---|
| `DELAY` | 3 seconds | How long to wait after wake or unlock before restarting the Dock |
| `COOLDOWN` | 30 seconds | The shortest gap between two automatic restarts |

```sh
DELAY=5 COOLDOWN=60 ./macos-dockwake.sh install
```

To change them later, run the install command again with the new values.

## Commands

| Command | What it does |
|---|---|
| `./macos-dockwake.sh install` | Builds and starts the watcher. Running it again rebuilds and restarts it. |
| `./macos-dockwake.sh reset` | Restarts the Dock right now. |
| `./macos-dockwake.sh status` | Shows whether the watcher is running, with its last 10 log lines. |
| `./macos-dockwake.sh uninstall` | Stops the watcher and removes everything it installed. |

## Files it installs

| Path | Contents |
|---|---|
| `~/Library/LaunchAgents/local.macos-dockwake.plist` | The LaunchAgent that starts the watcher at login |
| `~/Library/Application Support/macos-dockwake/` | The watcher's Swift source and compiled program |
| `~/Library/Logs/macos-dockwake.log` | The log of wake events and Dock restarts |

Nothing is installed outside your home folder, and no administrator password is needed. `uninstall` removes all three.

If you used an earlier version of this tool called spaces-fix, `install` and `uninstall` remove it too.

## Fixing it by hand

If the glitch shows up while you're using the Mac, run:

```sh
./macos-dockwake.sh reset
```

For a keyboard shortcut, make a shortcut in the Shortcuts app:

1. Open Shortcuts > Settings > Advanced, and turn on Allow Running Scripts.
2. Make a new shortcut with one Run Shell Script action containing `killall Dock`.
3. In the shortcut's details, click Add Keyboard Shortcut.

## Settings that make the glitches less frequent

None of these fix the bug, but together they reduce how often it happens:

- **Avoid native full screen.** Use Window > Fill instead, or hold Option while hovering over the green window button.
- **Mission Control settings.** In System Settings > Desktop & Dock, turn off "Automatically rearrange Spaces based on most recent use". Turn on "When switching to an application, switch to a Space with open windows for the application".
- **Accessibility settings.** In System Settings > Accessibility > Display, turn on Reduce Transparency and Reduce Motion.
- **Keep the Dock visible.** Turn off "Automatically hide and show the Dock".
- **Trackpad gestures.** In System Settings > Trackpad > More Gestures, set swiping between full-screen apps to three fingers. Turn off Three Finger Drag, which uses the same gesture.

## Limitations

- **It can't tell when the Dock is stuck.** It restarts the Dock after every wake and unlock, whether or not anything was wrong.
- **The Dock blinks for a moment** each time it restarts.
- **It can't fix glitches that start while you're using the Mac.** Use the `reset` command or the shortcut above.
- **The unlock event is undocumented.** If a future macOS version stops sending it, the wake events still trigger a restart.

## Troubleshooting

- **The build fails.** Check that `xcode-select -p` prints a folder. If it doesn't, run `xcode-select --install`.
- **The status says "not installed".** Run `./macos-dockwake.sh install` again and read any error it prints.
- **The log shows no restarts after wake.** Check that the watcher is loaded with `launchctl print gui/$(id -u)/local.macos-dockwake`.

## When to uninstall

Once a macOS update fixes the bug, run `./macos-dockwake.sh uninstall`. macOS 27.2 doesn't fix it, so check the release notes for 27.3 and later.

## License

MIT. See [LICENSE](LICENSE).
