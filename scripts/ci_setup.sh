#!/usr/bin/env bash
# Prepares a GitHub-hosted macos-26 runner for the repository's Task commands:
# selects the pinned Xcode (Swift 6 toolchain with swift-format) and installs
# Task. Local machines install Task once with Homebrew and do not need this.

set -euo pipefail

xcode="/Applications/Xcode_26.6.app/Contents/Developer"
if [[ -d "${xcode}" ]]; then
  sudo xcode-select -s "${xcode}"
fi
xcodebuild -version
swift --version

if ! command -v task >/dev/null; then
  brew install go-task
fi
