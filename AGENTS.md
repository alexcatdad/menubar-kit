# MenubarKit agent instructions

## Purpose

MenubarKit is the shared, first-party Swift package for the tray icon, status
panel and notifications of alexcatdad's macOS menu bar apps (Scratchpad,
paw-proxy, pr-nanny, usb-boop). Scratchpad's macOS app is the golden standard:
this package is extracted from it, and visual or behavioural changes here
should keep every app looking and behaving like Scratchpad.

## Invariants

- Zero third-party dependencies, including test-only and build-tool ones.
- Swift 6 language mode with strict concurrency; minimum macOS 13.
- Tray glyphs are 18x18pt template images loaded from `<name>.png` (18 px) and
  `<name>@2x.png` (36 px). Loading fails closed and the caller shows an SF
  Symbol fallback.
- Every `StatusTone` has its own SF Symbol shape. Meaning is never conveyed by
  colour alone; colour only reinforces the shape.
- The tray glyph never changes. Any tone other than `.ok` adds the heavy 9pt
  `exclamationmark` badge, composited into the same template image because
  `MenuBarExtra` drops a second image in its label. VoiceOver reads exactly "<App>, <status word>".
- Notifications only go through `UNUserNotificationCenter` so they are
  attributed to the app bundle. Never `osascript`, `sh`, `terminal-notifier`
  or any other process.
- Notifications are opt-in (default off). Permission (`[.alert, .sound]` only)
  is requested only from a user action. Every delivery re-checks the user's
  toggle and macOS permission. Delivery is silent unless the app enables sound.
  Click handling and foreground presentation are opt-in; foreground is off by default.
- The incident de-duplicator reports one incident and at most one recovery per
  condition, and recovery only after a reported incident.
- Keep app-specific wording and state mapping in the apps, not here.

## Layout

- `Package.swift`: one library product, `MenubarKit`.
- `Sources/MenubarKit/TrayIconLoader.swift`: 18pt template image loading and validation.
- `Sources/MenubarKit/StatusTone.swift`: `StatusTone`, `MenubarStatus`, `MenubarStatusRow`, `VersionLabel`,
  `TrayAccessibility`.
- `Sources/MenubarKit/Theme.swift`: `MenubarTheme` (accent, accent ink, ink; Scratchpad amber default).
- `Sources/MenubarKit/TrayIconComposer.swift`: glyph + badge composited into one template image.
- `Sources/MenubarKit/TrayLabel.swift`: the `MenuBarExtra` label view.
- `Sources/MenubarKit/Panel.swift`: 340pt panel building blocks, button styles and `RefreshButton`.
- `Sources/MenubarKit/Notifier.swift`: `MenubarNotifier`, `NotificationCenterClient`,
  `SystemNotificationCenter`, preferences.
- `Sources/MenubarKit/NotificationResponder.swift`: opt-in click/foreground delegate.
- `Sources/MenubarKit/SettingsOpener.swift`: open the Settings scene from an LSUIElement app.
- `Sources/MenubarKit/IncidentDeduplicator.swift`: incident/recovery coalescing.
- `Tests/MenubarKitTests/`: Swift Testing suites; `Fixtures/` holds tray PNGs (excluded from the target, read via
  `#filePath`).

## Build & verify

Requires Xcode with Swift 6 and [Task](https://taskfile.dev).

```sh
task check     # lint + build + test + security + git diff --check
task lint      # swift format lint --strict
task build     # swift build --build-tests -Xswiftc -warnings-as-errors
task test      # swift test with the 87% MenubarKit line-coverage floor
task security  # scripts/check_security.sh: no dependencies, no subprocesses
task format    # swift format format --in-place
```

CI (`.github/workflows/validation.yml`) calls `alexcatdad/ci-actions` at a
pinned commit: lint, build and test on pull requests, test and security on
`main` and weekly, and CodeQL (`swift`, `actions`). The `main` ruleset requires
`pr / leaks`, `pr / lint`, `pr / build`, `pr / deps`, plus the code-scanning
rule (`codeql / <lang>` checks). `scripts/ci_setup.sh` selects Xcode and
installs Task on the runner. CI validates only; it never tags or publishes.

`UNUserNotificationCenter` needs a real app bundle, so tests drive
`MenubarNotifier` through a fake `NotificationCenterClient`. SwiftUI views are
rendered offscreen in `ViewRenderTests` and verified by adopting them in an
app; describe visual changes in the PR.

## Release

- Versions are CalVer `vYYYY.MM.DD.N` (zero-padded month and day, `N` from 1
  per day), as annotated tags on `main` after `task check` passes.
- Move the **Unreleased** section of `CHANGELOG.md` under the new version in
  the same PR before tagging.
- SwiftPM cannot resolve four-part tags, so apps pin the tag's commit with
  `.package(url:, revision:)` and name the tag in a comment. Never ask apps to
  track a branch.
- Only tag a release when explicitly asked. Apps adopt new tags in their own PRs.

## Git

- `main` is the default branch. Work on a branch and open a PR; keep commits
  small and coherent.
- Never commit `.build/`, `.swiftpm/`, Xcode user data or secrets.
- Do not rewrite published history or move tags.

## Memory

Durable project memory lives in the Scratchpad MCP project `menubar-kit`.
Record decisions, constraints and findings there (for example API decisions
and adoption notes from each app) rather than in ad-hoc files.
