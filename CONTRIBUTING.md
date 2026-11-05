# Contributing

MenubarKit is the shared tray, panel and notification layer for alexcatdad's
macOS menu bar apps. Scratchpad is the reference look and feel; changes should
keep every app consistent with it rather than add per-app options.

Before opening a PR, run from the repository root (Xcode with Swift 6 and
[Task](https://taskfile.dev) installed):

```sh
task check
```

That runs `swift format lint --strict`, a warnings-as-errors build of library
and tests, `swift test` and `git diff --check`. Use `task format` to fix
formatting.

- Keep zero third-party dependencies, including test-only ones.
- Keep Swift 6 strict concurrency and macOS 13 as the minimum.
- Add or update tests for behaviour changes; UI changes should describe the
  before/after in the PR.
- Note public API changes in `CHANGELOG.md` under **Unreleased**. Breaking
  changes need a migration note, because every app pins an exact tag.
- Keep commits small and coherent. Resolve review feedback on the latest commit.
