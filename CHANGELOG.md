# Changelog

All notable changes are listed here. Versions use CalVer `vYYYY.MM.DD.N`
(`N` starts at 1 for the first release of a day). Consumers pin an exact tag.

## Unreleased

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
