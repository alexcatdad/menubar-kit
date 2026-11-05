# Changelog

All notable changes are listed here. Versions use CalVer `vYYYY.MM.DD.N`
(`N` starts at 1 for the first release of a day). Consumers pin an exact tag.

## Unreleased

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
