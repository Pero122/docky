#!/usr/bin/env bash
#
# Standalone test runner for Docky.
#
# Docky's Xcode project has no XCTest/unit-test target, so pure-logic
# regression tests live here and are compiled with `swiftc` against the real
# source files. Each test is a `@main` entry point compiled together with the
# specific source file(s) it exercises.
#
# Usage:  ./Tests/standalone/run.sh         (run from anywhere)
# Exit:   non-zero if any test fails.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0

run_case() {
    local name="$1"; shift          # test name
    local bin="$TMP/$name"
    echo "── $name ─────────────────────────────"
    if xcrun swiftc "$@" -o "$bin" && "$bin"; then
        :
    else
        fail=1
    fi
    echo ""
}

# DockHoverGeometry — multi-display hover-overlay screen resolution.
run_case "DockHoverGeometry" \
    "$ROOT/Docky/Services/DockHoverGeometry.swift" \
    "$ROOT/Tests/standalone/DockHoverGeometryTests.swift"

if [ "$fail" -eq 0 ]; then
    echo "All standalone tests passed ✅"
else
    echo "Some standalone tests FAILED ❌"
fi
exit "$fail"
