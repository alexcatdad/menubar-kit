#!/usr/bin/env bash
# Runs the tests with coverage (warnings as errors) and fails when line
# coverage of the MenubarKit library sources drops below the floor.

set -euo pipefail
cd "$(dirname "$0")/.."

target=MenubarKit
tests=MenubarKitTests
floor=87

swift test --enable-code-coverage -Xswiftc -warnings-as-errors
codecov=$(dirname "$(swift test --show-codecov-path)")
bin=$(dirname "$codecov")
# The native build system puts every test target in one <Package>PackageTests
# bundle; swiftbuild makes one bundle per test target. Use whichever exists.
bundle=
for name in "$tests" MenubarKitPackageTests; do
  if [[ -f "$bin/$name.xctest/Contents/MacOS/$name" ]]; then
    bundle="$bin/$name.xctest/Contents/MacOS/$name"
    break
  fi
done
if [[ -z "$bundle" ]]; then
  echo "error: no test bundle for $tests under $bin" >&2
  ls "$bin" >&2
  exit 1
fi
mkdir -p .build/coverage
summary=.build/coverage/summary.txt
xcrun llvm-cov report "$bundle" \
  -instr-profile "$codecov/default.profdata" \
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
