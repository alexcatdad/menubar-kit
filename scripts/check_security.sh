#!/usr/bin/env bash
# Checks the invariants in AGENTS.md that a compiler cannot:
# - zero third-party dependencies (no .package entries, no Package.resolved);
# - notifications only through UNUserNotificationCenter: no child processes,
#   AppleScript or shell fallbacks anywhere in the library sources.

set -euo pipefail
cd "$(dirname "$0")/.."

status=0

if grep -nE '\.package\(' Package.swift; then
  echo "error: Package.swift declares a package dependency" >&2
  status=1
fi

if [[ -e Package.resolved ]]; then
  echo "error: Package.resolved exists; the package must have no dependencies" >&2
  status=1
fi

# Comment lines are skipped so documentation may name what is forbidden.
if grep -rnE '\b(Process|NSTask|NSAppleScript|OSAScript)\b|osascript|terminal-notifier|/bin/(ba|z)?sh' Sources \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'; then
  echo "error: library sources must not launch processes or scripts" >&2
  status=1
fi

if [[ ${status} -eq 0 ]]; then
  echo "security invariants hold"
fi
exit "${status}"
