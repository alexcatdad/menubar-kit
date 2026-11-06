#!/usr/bin/env bash
# Runs the tests with coverage (warnings as errors) and fails when line
# coverage of the MenubarKit library sources drops below the floor.

set -euo pipefail
cd "$(dirname "$0")/.."

target=MenubarKit
tests=MenubarKitTests
floor=87

swift test --enable-code-coverage -Xswiftc -warnings-as-errors
bin=$(swift build --show-bin-path)
mkdir -p .build/coverage
summary=.build/coverage/summary.txt
xcrun llvm-cov report "$bin/$tests.xctest/Contents/MacOS/$tests" \
  -instr-profile "$bin/codecov/default.profdata" \
  "$PWD/Sources/$target" >"$summary"

# Line coverage is the tenth column of the TOTAL row.
total=$(awk '/^TOTAL/ { gsub(/%/, "", $10); print $10 }' "$summary")
if [[ -z "$total" ]]; then
  echo "error: could not read total coverage from $summary" >&2
  exit 1
fi
if ! awk -v total="$total" -v floor="$floor" 'BEGIN { exit !(total >= floor) }'; then
  cat "$summary" >&2
  echo "error: $target line coverage $total% is below the $floor% floor" >&2
  exit 1
fi
echo "$target line coverage: $total% ($floor% floor)"
