//
//  DockResizeGeometryTests.swift
//  Docky — standalone tests
//
//  Docky has no XCTest target, so pure-logic regression tests live here and
//  run via `Tests/standalone/run.sh` (compiles the real source file together
//  with the test using `swiftc`). See Tests/README.md.
//
//  Covers drag-to-resize: mapping a vertical drag on the dock's separator /
//  top edge into a new tile size. POSITIVE dragDeltaY grows the dock (drag the
//  top edge up), negative shrinks it, and the result is clamped to bounds.
//

import Foundation

@main
enum DockResizeGeometryTests {
    static var failures = 0

    static func check(_ cond: Bool, _ msg: String) {
        if cond { print("  ✅ \(msg)") }
        else { print("  ❌ \(msg)"); failures += 1 }
    }

    static func main() {
        let bounds: ClosedRange<CGFloat> = 32...128

        print("Test: drag up (positive delta) grows the tile size")
        let grown = DockResizeGeometry.tileSize(forDragDeltaY: 20, startTileSize: 48, bounds: bounds)
        check(grown == 68, "48 + 20 = 68 (got \(grown))")

        print("Test: drag down (negative delta) shrinks the tile size")
        let shrunk = DockResizeGeometry.tileSize(forDragDeltaY: -20, startTileSize: 64, bounds: bounds)
        check(shrunk == 44, "64 - 20 = 44 (got \(shrunk))")

        print("Test: zero delta is a no-op")
        let same = DockResizeGeometry.tileSize(forDragDeltaY: 0, startTileSize: 48, bounds: bounds)
        check(same == 48, "no movement keeps size (got \(same))")

        print("Test: clamps at max")
        let big = DockResizeGeometry.tileSize(forDragDeltaY: 1000, startTileSize: 48, bounds: bounds)
        check(big == 128, "huge upward drag clamps to max 128 (got \(big))")

        print("Test: clamps at min")
        let small = DockResizeGeometry.tileSize(forDragDeltaY: -1000, startTileSize: 48, bounds: bounds)
        check(small == 32, "huge downward drag clamps to min 32 (got \(small))")

        print("Test: gain scales the drag-to-size ratio")
        let geared = DockResizeGeometry.tileSize(forDragDeltaY: 10, startTileSize: 48, gain: 2, bounds: bounds)
        check(geared == 68, "48 + 10*2 = 68 (got \(geared))")

        if failures == 0 { print("\nALL PASSED ✅"); exit(0) }
        else { print("\n\(failures) FAILURE(S) ❌"); exit(1) }
    }
}
