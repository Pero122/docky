# Tests

Docky's Xcode project has no XCTest/unit-test target. Pure-logic regression
tests therefore live here as **standalone Swift programs** compiled with
`swiftc` against the real source files.

## Running

```sh
./Tests/standalone/run.sh
```

Exits non-zero if any test fails. Each case in `run.sh` compiles one `@main`
test file together with the specific source file(s) it exercises.

## Adding a test

1. Extract the logic under test into a pure, AppKit-window-free helper (see
   `Docky/Services/DockHoverGeometry.swift` — the thin live wrappers that feed
   it `NSApp` / `NSEvent` / `NSScreen` values stay in the view layer and are
   verified on hardware).
2. Add a `@main enum XxxTests { static func main() { ... } }` file under
   `Tests/standalone/` that exits non-zero on failure.
3. Add a `run_case` line to `Tests/standalone/run.sh`.

## Current tests

- **DockHoverGeometry** — multi-display hover-overlay screen resolution
  (regression: hover on a non-primary display rendered the window
  preview / widget expansion on the wrong screen).
