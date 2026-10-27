# macos-dockwake

Restarts the macOS Dock automatically after your Mac wakes or unlocks, to clear window-management glitches in macOS 27 (Golden Gate). Press **Control-Option-Command-D** to restart the Dock any time.

## Install

1. Download the latest **macos-dockwake-….dmg** from the [Releases page](https://github.com/RosBradley/macos-dockwake/releases/latest).
2. Open the downloaded file, and drag **macos-dockwake** onto the **Applications** folder.
3. Open **macos-dockwake** from your Applications folder.
4. macOS says it can't check the app for malicious software. Click **Done**.
5. Open **System Settings > Privacy & Security**. Scroll down to the message about macos-dockwake, and click **Open Anyway**. Enter your password if asked.
6. In the welcome message, click **Start at Login**.

Its icon, a small Dock symbol, then appears in the menu bar at the top right of your screen. You only approve the app once.

**Why macOS warns about it.** Apple only skips that warning for apps signed with a paid Apple Developer account. macos-dockwake isn't, but its full source code is in this repository, and the app is built from it by GitHub, not on someone's own computer. See [Building the app](#building-the-app) for how.

Requires macOS 13 or later, on Apple silicon or Intel.

## Using it

Click the menu bar icon for these options:

| Menu item | What it does |
|---|---|
| Restart Dock Now | Restarts the Dock right away. Same as pressing Control-Option-Command-D. |
| Restart Dock After Wake or Unlock | Turns the automatic restart on or off. It starts on. |
| Start at Login | Opens macos-dockwake automatically when you log in. |
| Show Log | Opens the log of wake events and Dock restarts in the Console app. |
| Quit macos-dockwake | Stops it until you open it again. |

The app has no Dock icon. If the menu bar icon is hidden behind the camera notch or other icons, open macos-dockwake from the Applications folder again, and it will tell you it's running.

**If the glitch shows up while you're using the Mac**, press **Control-Option-Command-D**. The Dock restarts at once, without the usual delay. The shortcut works in any app and needs no extra permissions. Locking the screen with Control-Command-Q and unlocking it works too.

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

1. macos-dockwake waits in the background for three events: the system waking, the display waking and the screen unlocking.
2. Three seconds after any of them, it restarts the Dock and writes a line to its log.
3. These events often arrive together, so after one restart it ignores further events for 30 seconds. That way the Dock restarts only once per wake.

It uses almost no CPU or memory, since it just waits for events.

The log is at `~/Library/Logs/macos-dockwake.log`. A typical wake looks like this:

```
display wake: restarting Dock in 3s
system wake: skipped, a Dock restart was already triggered 0s ago
screen unlock: skipped, a Dock restart was already triggered 2s ago
Dock restarted (killall exit 0)
```

**Changing the timings.** There's no menu for these. In Terminal, run one of these, then quit and reopen the app:

```sh
defaults write io.github.rosbradley.macos-dockwake Delay -float 5      # seconds to wait after wake
defaults write io.github.rosbradley.macos-dockwake Cooldown -float 60  # seconds between automatic restarts
```

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
- **It can't fix glitches that start while you're using the Mac.** Press Control-Option-Command-D instead.
- **The unlock event is undocumented.** If a future macOS version stops sending it, the wake events still trigger a restart.

## Troubleshooting

- **There's no Open Anyway button.** It only appears for about an hour after you try to open the app. Open macos-dockwake again, then go back to Privacy & Security.
- **Start at Login doesn't turn on.** Make sure the app is in your Applications folder, not Downloads or the disk image. You can also add it in System Settings > General > Login Items & Extensions, with the + button under Open at Login.
- **The keyboard shortcut does nothing.** Choose Show Log and look for "keyboard shortcut unavailable". That means another app already uses Control-Option-Command-D. The Restart Dock Now menu item still works.
- **The log shows no restarts after wake.** Check that Restart Dock After Wake or Unlock has a check mark.

## Uninstall

1. Click the menu bar icon and choose **Quit macos-dockwake**.
2. If Start at Login was on, turn it off first, or remove macos-dockwake in System Settings > General > Login Items & Extensions.
3. Drag macos-dockwake from Applications to the Trash.

To remove its log too, delete `~/Library/Logs/macos-dockwake.log`.

**When to uninstall.** Once a macOS update fixes the bug, you won't need it. macOS 27.2 doesn't fix it, so check the release notes for 27.3 and later.

## Terminal version

The original version of macos-dockwake is a script with no menu bar icon. It does the same thing, including the keyboard shortcut, but it compiles itself on your Mac and runs as a LaunchAgent. It needs the Xcode Command Line Tools (`xcode-select --install`).

Use either the app or the Terminal version, not both. When the app finds the Terminal version, it offers to remove it.

```sh
git clone https://github.com/RosBradley/macos-dockwake.git
cd macos-dockwake
./macos-dockwake.sh install
```

| Command | What it does |
|---|---|
| `./macos-dockwake.sh install` | Builds and starts the watcher. Running it again rebuilds and restarts it. |
| `./macos-dockwake.sh reset` | Restarts the Dock right now. |
| `./macos-dockwake.sh status` | Shows whether the watcher is running, with its last 10 log lines. |
| `./macos-dockwake.sh uninstall` | Stops the watcher and removes everything it installed. |

To change the timings, pass them to `install`, for example `DELAY=5 COOLDOWN=60 ./macos-dockwake.sh install`.

It installs these files, all in your home folder, with no administrator password:

| Path | Contents |
|---|---|
| `~/Library/LaunchAgents/local.macos-dockwake.plist` | The LaunchAgent that starts the watcher at login |
| `~/Library/Application Support/macos-dockwake/` | The watcher's Swift source and compiled program |
| `~/Library/Logs/macos-dockwake.log` | The log of wake events and Dock restarts |

If you used an earlier version of this tool called spaces-fix, `install` and `uninstall` remove it too.

## Building the app

The app's source code is in `app/Sources`. To build it yourself, with Xcode or the Xcode Command Line Tools installed:

```sh
scripts/build-app.sh
```

That creates `build/macos-dockwake.app`, plus a disk image and a zip.

**Publishing a release.** Push a version tag, and GitHub Actions builds the app and attaches the disk image and zip to a new release:

```sh
git tag v1.0.1
git push origin v1.0.1
```

To test a build without publishing, open the Actions tab, choose Release, and click Run workflow. The files appear under the run's Artifacts.

## License

MIT. See [LICENSE](LICENSE).
