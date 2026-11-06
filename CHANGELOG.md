# Changelog

All notable changes are listed here. Versions use CalVer `vYYYY.MM.DD.N`
(`N` starts at 1 for the first release of a day). Consumers pin an exact tag.

## Unreleased

### Added

- An 87% line-coverage floor on `MenubarKit` in `task test` (`scripts/coverage.sh`), and render tests for the
  panel, list-row, settings and tray views.
- CI through `alexcatdad/ci-actions` (lint, build, test, security, CodeQL) and a `task security` invariant check.
- `MenuSection`'s Quit row answers ⌘Q.
- `MenubarNotifier.requestPermission()` throws the error macOS returned instead of reporting `.denied`, and
  `PermissionRequestError.alreadyInProgress` while another request is open; `isRequestingPermission`.
  `userEnabledNotifications()` uses it and keeps its old results.
- `MenubarNotifier.permissionUpdates(every:)`: the permission now and on every change, for Settings views.
- `deliver` returns `DeliveryOutcome.cancelled` (a `.failed("cancelled")` constant, so existing switches still
  compile) when the task is cancelled, including between the permission check and posting.
- `ListRowButton` and `ListRowButtonStyle`: a clickable two-line row (title, subtitle, optional icon and value)
  with hover.
- `StatusHeader` and `PanelNotice` accept `AttributedString`; `InlineCode.attributed(_:)` turns backtick spans
  into inline code without interpreting other Markdown.
- `SettingsForm`, `SettingsNote`, `NotificationSettingsSection` (toggle, sound, live permission note, link to
  System Settings) and `SettingsAboutSection`.
- `TrayGlyphRenderer` and the `make-tray-glyph` executable write the 1x/2x tray PNGs from an SF Symbol or a
  custom drawing.

## v2026.11.05.1

### Fixed

- The attention badge now shows in the menu bar. `MenuBarExtra` renders only one image from its label, so
  `TrayLabel` draws the glyph and badge into a single template image (`TrayIconComposer`).

### Added

- `MenubarNotification.subtitle` and `userInfo` (`[String: String]`); `SystemNotificationCenter.content(for:playSound:)`.
- `MenubarNotificationResponder`: opt-in `UNUserNotificationCenterDelegate` that hands clicks (`NotificationClick`
  with `userInfo`) to the app on the main actor; foreground presentation is opt-in and off by default.
- `OpenSettingsButton` and `SettingsOpener`: open the `Settings` scene from an LSUIElement app (activate, open,
  bring to front) on macOS 13 and 14+.
- `RefreshButton` and `HeaderIconButtonStyle`; `StatusHeader` takes an optional trailing `accessory`.

### Initial extraction

### Added

- `TrayIconLoader`: 18x18pt template image from `<name>.png` / `<name>@2x.png`, failing closed on missing,
  mis-sized, alpha-less or fully transparent files.
- `StatusTone` (ok, warning, error, off, update), each with its own SF Symbol shape; `MenubarStatus`,
  `MenubarStatusRow`, `VersionLabel`, `TrayAccessibility`.
- `TrayLabel`: `MenuBarExtra` label with constant glyph, heavy 9pt attention badge, DEV caption and
  "<App>, <status>" VoiceOver label.
- Panel building blocks: `MenubarPanel` (340pt), `StatusHeader`, `StatusIcon`, `StatusRowView`,
  `StatusRowsTile`, `TileHeader`, `.groupedTile()`, `MenuSection`, `MenuRowButtonStyle`,
  `ProminentButtonStyle`, `PrimaryActionButton`, `PanelNotice`, `VersionFooter`, `MenubarTheme`.
- `MenubarNotifier`: opt-in `UNUserNotificationCenter` wrapper, silent by default, with thread identifiers and
  per-delivery permission re-checks.
- `IncidentDeduplicator`: one incident and one recovery per condition, with configurable delay thresholds.
