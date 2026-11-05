# MenubarKit

Shared tray icon, status panel and notification building blocks for
alexcatdad's macOS menu bar apps (Scratchpad, paw-proxy, pr-nanny, usb-boop).
Extracted from Scratchpad, which is the reference look and feel.

- 18pt template tray glyph that never changes shape, a heavy attention badge
  for any non-OK state (drawn into the same template image, since
  `MenuBarExtra` shows only one image), a DEV caption, and a VoiceOver label of
  "<App>, <status>".
- Five status tones, each with its own SF Symbol, so state never depends on
  colour alone.
- A 340pt panel: status header, grouped tile rows, primary action, menu rows,
  version footer.
- Native, opt-in notifications through `UNUserNotificationCenter`, attributed
  to the app bundle (no `osascript`, no shell), silent unless the app enables
  sound, and an incident de-duplicator (one incident, one recovery).

Swift 6 (strict concurrency), macOS 13+, no third-party dependencies.

## Install

Releases are CalVer tags `vYYYY.MM.DD.N`. SwiftPM only resolves semantic
versions, so a four-part CalVer tag cannot be used with `exact:` or `from:`.
Pin the tagged commit instead, and name the tag in a comment:

```swift
// Package.swift
dependencies: [
    // menubar-kit v2026.11.05.1
    .package(url: "https://github.com/alexcatdad/menubar-kit.git", revision: "<full commit SHA of the tag>"),
],
targets: [
    .executableTarget(name: "MyApp", dependencies: [.product(name: "MenubarKit", package: "menubar-kit")]),
]
```

Get the SHA with `git ls-remote https://github.com/alexcatdad/menubar-kit.git refs/tags/<tag>^{}`.

## Tray icon and label

Ship `MyAppTrayIcon.png` (18x18 px) and `MyAppTrayIcon@2x.png` (36x36 px),
black on transparent, in the app's `Contents/Resources`.

### Making the glyph

`make-tray-glyph` writes both PNGs from an SF Symbol. Run it from a
menu-bar-kit checkout (or the app's resolved copy under
`.build/checkouts/menubar-kit`) and commit the output:

```sh
swift run --package-path path/to/menubar-kit make-tray-glyph \
    --symbol pawprint.fill --name MyAppTrayIcon --output "$PWD/Resources" \
    [--point-size 15] [--weight regular]
```

For a custom shape, call `TrayGlyphRenderer` from a test or script that
imports MenubarKit. It draws in black into an 18x18pt rect (origin bottom left):

```swift
try TrayGlyphRenderer.write(baseName: "MyAppTrayIcon", to: resources) { rect in
    NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 3), xRadius: 3, yRadius: 3).fill()
}
```

Xcode projects: set `COMBINE_HIDPI_IMAGES = NO`, or Xcode merges the pair
into a TIFF and `TrayIconLoader` fails closed to the fallback symbol.

```swift
import MenubarKit
import SwiftUI

@main
struct MyApp: App {
    @StateObject private var model = AppModel()
    private let trayIcon = TrayIconLoader.load(resourcesDirectory: Bundle.main.resourceURL, baseName: "MyAppTrayIcon")

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(model)
        } label: {
            TrayLabel(
                icon: trayIcon,               // nil -> fallbackSymbol
                fallbackSymbol: "bolt.horizontal",
                status: model.status,         // MenubarStatus
                appName: "MyApp",
                isDevelopment: Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
            )
        }
        .menuBarExtraStyle(.window)
    }
}
```

## Panel

```swift
struct PanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        MenubarPanel {
            StatusHeader(model.status) {
                RefreshButton(isRefreshing: model.isRefreshing) { model.refresh() }
            }
            StatusRowsTile([
                MenubarStatusRow(title: "Service", value: "Running", tone: .ok),
                MenubarStatusRow(title: "Server", value: "Unreachable", tone: .warning),
            ])
            if model.status.tone != .ok {
                PrimaryActionButton("Try Again Now") { model.retry() }
            }
            MenuSection(quitTitle: "Quit MyApp") {
                Button("Open MyApp") { model.openWindow() }
                OpenSettingsButton()  // activates the LSUIElement app, opens Settings, brings it front
            }
            VersionFooter()
        }
    }
}
```

`MenuSection`'s Quit row answers ⌘Q while the panel is open.

Lists of things the user can open (routes, devices, pull requests) use
`ListRowButton` inside a grouped tile:

```swift
VStack(spacing: 0) {
    ForEach(model.routes) { route in
        ListRowButton(route.name, subtitle: route.url, tone: route.tone, value: route.port) {
            NSWorkspace.shared.open(route.link)
        }
    }
}
.groupedTile()
```

Helper and CLI messages often quote commands in backticks. Pass them through
`InlineCode.attributed(_:)` to show those spans as inline code. Only
backticks are interpreted, so paths with `*` or `_` stay literal:

```swift
StatusHeader(tone: .error, headline: "Helper stopped", detail: InlineCode.attributed(model.lastError))
PanelNotice(InlineCode.attributed("Run `up doctor` to check the CA."))
```

`MenubarStatus(tone:word:headline:detail:)` drives both the label and the
header. Tones: `.ok`, `.warning`, `.error`, `.off`, `.update`. The accent
defaults to Scratchpad amber; override with `.menubarTheme(MenubarTheme(...))`.

## Notifications

Notifications are off until the user turns them on. Bind a toggle to the
default keys and request permission only from that toggle:

```swift
@AppStorage(NotificationPreferences.enabledKey) private var notify = false
@AppStorage(NotificationPreferences.soundEnabledKey) private var sound = false  // optional
@State private var permission = NotificationPermission.notDetermined
let notifier = MenubarNotifier()

Toggle("Notify me about problems", isOn: $notify)
    .onChange(of: notify) { enabled in
        Task {
            permission = enabled ? await notifier.userEnabledNotifications() : await notifier.permission()
        }
    }
```

Every `deliver` re-reads the toggle and re-checks macOS permission:

```swift
await notifier.deliver(MenubarNotification(
    title: "MyApp server is offline",
    body: "Requests are queued until it is back.",
    threadIdentifier: "outage"
))
```

Optional extras: `subtitle`, and `userInfo` that comes back on click. To
handle clicks, install a responder once at launch and keep it alive:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    let responder = MenubarNotificationResponder(presentInForeground: false) { click in
        guard !click.isDismissal, let url = click.userInfo["url"].flatMap(URL.init(string:)) else { return }
        NSWorkspace.shared.open(url)
    }
    func applicationDidFinishLaunching(_ notification: Notification) { responder.install() }
}
```

`presentInForeground` (default `false`) controls whether banners show while
the app is active.

`requestPermission()` is the throwing form of `userEnabledNotifications()`:
it surfaces the error macOS returned and refuses a second request while one is
open (`PermissionRequestError.alreadyInProgress`). `permissionUpdates()`
yields the permission now and on every change (for example after the user
changes it in System Settings); iterate it in a view's `.task`. `deliver`
returns `.cancelled` without posting if its task is cancelled.

## Settings

`SettingsForm` is the shared Settings layout (a grouped form, 460pt wide).
`NotificationSettingsSection` is the whole opt-in: the toggle, an optional
sound toggle, a note that follows macOS permission live, and a button to
System Settings when notifications are blocked.

```swift
Settings {
    SettingsForm {
        NotificationSettingsSection(
            notifier: model.notifier,
            toggleTitle: "Notify me when a project goes live",
            explanation: "Silent unless you turn on the sound."
        )
        Section("Startup") {
            Toggle("Launch at login", isOn: $launchAtLogin)
            SettingsNote("Dev builds never register a login item.")
        }
        SettingsAboutSection(note: "MyApp never uploads your data.", repository: URL(string: "https://github.com/alexcatdad/myapp"))
    }
}
```

## Incident de-duplication

```swift
enum Incident: Hashable, Sendable { case outage, storage }

var incidents = IncidentDeduplicator<Incident>(
    delays: [.outage: 60],   // report only after 60s of continuous outage
    reportedIncidents: restoredFromUserDefaults
)

// On every poll:
if let change = incidents.observe(.outage, isActive: serverUnreachable) {
    switch change {
    case .incident: await notifier.deliver(...)  // once
    case .recovered: await notifier.deliver(...) // once, only after a reported incident
    }
}
// Persist incidents.reportedIncidents to survive relaunch; call reset(_:) when
// the user deliberately stopped what was failing.
```

## Development

```sh
task check   # lint, warnings-as-errors build, swift test
```

See [CONTRIBUTING.md](CONTRIBUTING.md). MIT licensed.
