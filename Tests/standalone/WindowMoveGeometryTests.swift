//
//  WindowMoveGeometryTests.swift
//  Docky — standalone tests
//
//  Docky has no XCTest target, so pure-logic regression tests live here and run
//  via `Tests/standalone/run.sh` (compiles the real source file together with the
//  test using `swiftc`). See Tests/README.md.
//
//  Covers move-window-to-screen (the dock window-preview "pull onto the screen I
//  clicked" action): preserve size (clamped to the destination), keep proportional
//  position, and clamp so the window stays fully inside the visible frame.
//  Geometry uses power-of-2 fractions so the proportional math is exact.
//

import Foundation
import CoreGraphics

@main
enum WindowMoveGeometryTests {
    static var failures = 0

    static func check(_ cond: Bool, _ msg: String) {
        if cond { print("  ✅ \(msg)") }
        else { print("  ❌ \(msg)"); failures += 1 }
    }

    static func eq(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX == b.minX && a.minY == b.minY && a.width == b.width && a.height == b.height
    }

    static func main() {
        // Two equal 1024² screens side by side (B is to the right of A).
        let a = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        let b = CGRect(x: 1024, y: 0, width: 1024, height: 1024)

        print("Test: proportional position is preserved on the destination screen")
        let r1 = WindowMoveGeometry.targetFrame(
            windowFrame: CGRect(x: 256, y: 128, width: 300, height: 400),
            from: a, to: b, visible: b)
        check(eq(r1, CGRect(x: 1280, y: 128, width: 300, height: 400)),
              "rel (0.25,0.125) of A maps to the same rel on B, size kept (got \(r1))")

        print("Test: size is clamped down to a smaller destination screen")
        let smallB = CGRect(x: 1024, y: 0, width: 512, height: 512)
        let r2 = WindowMoveGeometry.targetFrame(
            windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            from: a, to: smallB, visible: smallB)
        check(eq(r2, CGRect(x: 1024, y: 0, width: 512, height: 512)),
              "800x600 clamped to 512x512 (got \(r2))")

        print("Test: position is clamped so the window stays fully on-screen")
        let r3 = WindowMoveGeometry.targetFrame(
            windowFrame: CGRect(x: 896, y: 896, width: 256, height: 256),
            from: a, to: b, visible: b)
        check(eq(r3, CGRect(x: 1792, y: 768, width: 256, height: 256)),
              "near-edge window pulled in to fit (x 1920->1792, y 896->768) (got \(r3))")

        print("Test: respects the destination visible frame (menu bar / Dock inset)")
        let visB = CGRect(x: 1024, y: 64, width: 1024, height: 896)
        let r4 = WindowMoveGeometry.targetFrame(
            windowFrame: CGRect(x: 512, y: 896, width: 400, height: 400),
            from: a, to: b, visible: visB)
        check(eq(r4, CGRect(x: 1536, y: 560, width: 400, height: 400)),
              "clamped to the visible top inset (y 896->560) (got \(r4))")

        if failures == 0 { print("\nALL PASSED ✅"); exit(0) }
        else { print("\n\(failures) FAILURE(S) ❌"); exit(1) }
    }
}
