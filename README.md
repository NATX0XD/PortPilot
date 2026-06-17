# PortPilot

**English** · [ไทย](README.th.md)

A native macOS app for monitoring the services/projects currently running — see which port each one uses, **Restart** them (kill and re-run the original command) or **Close** them (stop the process). It runs as both a **full desktop window (with a Dock icon)** and a **menu-bar item** that shows a badge counting your services.

<!-- Add a screenshot here: ![PortPilot](docs/screenshot.png) -->

## Features
- Scans all listening TCP services with `lsof` (auto-refresh every 5s)
- Shows port, name, PID, protocol, user, uptime, and working directory
- Groups into **Pinned / Your services / System** + pin your favorites
- **USER/SYSTEM** badges derived from the executable path (catches Apple daemons running under your account)
- **Restart**: reads the real argv via `KERN_PROCARGS2` and re-spawns directly (no shell — commands with spaces/quotes don't get mangled)
- **Close**: SIGTERM → SIGKILL with a PID-reuse guard (re-checks via `lsof` that the PID still owns the port before signalling)
- **Inline confirm** before kill/restart (works in both the window and the menu bar)
- Name a project per port (persisted) + search/filter
- Right-click: open `localhost:PORT`, copy port/PID/URL/command/cwd, Reveal in Finder, Open in Terminal
- **Show system** (admin): scans with root privileges to reveal root/other-user listeners (one prompt per session, cached)
- Freshness indicator ("updated Ns ago") + a dismissible error banner
- Action buttons are enabled only for your own (`.user`) processes, to avoid accidentally killing Apple daemons

## Download & use (no build required)
1. Go to **[Releases](https://github.com/NATX0XD/PortPilot/releases/latest)** and download `PortPilot-x.y.z.zip` (Apple Silicon).
2. Unzip and move **PortPilot.app** to `/Applications`.
3. **First launch:** right-click the app → **Open** → **Open** again in the dialog.
   The app is ad-hoc signed (not notarized), so a normal double-click is blocked by Gatekeeper the first time only.
   If macOS still refuses, clear the quarantine flag once:
   ```bash
   xattr -dr com.apple.quarantine /Applications/PortPilot.app
   ```
4. PortPilot opens a window and a 📡 menu-bar icon, and auto-starts at login. The current version is shown in the footer.

## Build & run
```bash
cd PortPilot
./scripts/install.sh        # build + install to /Applications + auto-start at login + open
# or just build:
./scripts/build-app.sh && open PortPilot.app
```
After launch you'll get the PortPilot window plus a 📡 icon in the menu bar (with a badge counting your services).

## Releasing (versioning)
The version lives in `scripts/Info.plist` (`CFBundleShortVersionString`) and is shown in the app footer.

- **Locally (with a Mac):** one command bumps the version, builds, zips, tags, and publishes:
  ```bash
  ./scripts/release.sh 1.0.1
  ```
- **From GitHub (no Mac needed):** Actions tab → **Build & Release** → Run workflow → enter the version.
  It builds on a macOS runner and publishes the release. (Use one path or the other, not both for the same version.)

## Uninstall
```bash
launchctl unload ~/Library/LaunchAgents/com.portpilot.app.plist
rm ~/Library/LaunchAgents/com.portpilot.app.plist
rm -rf /Applications/PortPilot.app
```

## Project structure
```
PortPilot/
├── Package.swift                 # SPM manifest (fallback — build-app.sh is the primary path)
├── README.md
├── scripts/
│   ├── make-icon.sh / .swift     # generate AppIcon.icns
│   ├── build-app.sh              # compile + package into PortPilot.app
│   ├── install.sh                # build + install + login auto-start
│   └── Info.plist                # bundle config
└── Sources/PortPilot/
    ├── PortPilotApp.swift        # @main: AppKit NSWindow (desktop) + MenuBarExtra
    ├── ContentView.swift         # UI: sections, inline confirm/rename, context menu
    ├── AppModel.swift            # state, auto-refresh, pins, sections, actions
    ├── PortScanner.swift         # parse lsof + ps -> ServiceInfo
    ├── ProcessManager.swift      # close / restart (PID-reuse guard)
    ├── Shell.swift               # run (with timeout), argv via sysctl, spawn
    └── Models.swift              # ServiceInfo + USER/SYSTEM category
```

## Requirements / toolchain
Needs Command Line Tools whose compiler and SDK match (install fresh with `xcode-select --install`).
If you hit an error like `this SDK is not supported by the compiler`, reinstall CLT:
```bash
sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install
```

## License
MIT
