//
//  DockHoverGeometryTests.swift
//  Docky — standalone tests
//
//  Docky has no XCTest target, so pure-logic regression tests live here and
//  run via `Tests/standalone/run.sh` (compiles the real source file together
//  with the test using `swiftc`). See Tests/README.md.
//
//  Covers the multi-display "wrong-screen hover overlay" regression: in
//  `.allDisplays` mode there is one dock per screen, so hover-driven overlays
//  must resolve the dock the cursor is over instead of always taking the first
//  window — otherwise the overlay converts coordinates against the wrong dock
//  and renders on the wrong display.
//

import Foundation

@main
enum DockHoverGeometryTests {
    static var failures = 0

    static func check(_ cond: Bool, _ msg: String) {
        if cond { print("  ✅ \(msg)") }
        else { print("  ❌ \(msg)"); failures += 1 }
    }

    static func main() {
        // Synthetic two-display layout (AppKit screen coords, bottom-left
        // origin). Screen 1: 1920x1080 at origin. Screen 2: to its right.
        // Each dock spans its screen's width along the bottom (height 90).
        let dock1 = CGRect(x: 0,    y: 0, width: 1920, height: 90)   // screen 1 dock
        let dock2 = CGRect(x: 1920, y: 0, width: 1920, height: 90)   // screen 2 dock
        let candidates = [dock1, dock2]                             // NSApp order: screen 1 first

        // A tile hovered on SCREEN 2's dock. Window-local rect (SwiftUI
        // top-left, relative to dock2's hosting view): ~1000pt from its left.
        let tileLocal = CGRect(x: 1000, y: 10, width: 60, height: 60)
        let cursorOnScreen2 = CGPoint(x: 1920 + 1000 + 30, y: 45)   // (2950, 45) — inside dock2

        print("Test: hover on screen 2 resolves to screen 2's dock")
        let chosen = DockHoverGeometry.dockFrame(under: cursorOnScreen2, candidates: candidates)
        check(chosen == dock2, "dockFrame(under:) picks the dock the cursor is over (dock2)")

        let converted = DockHoverGeometry.convertToScreen(tileLocal, dockFrame: chosen ?? dock1)
        check(converted.minX >= 1920, "converted rect lands on screen 2 (minX \(converted.minX) >= 1920)")
        check(converted.maxX <= 3840, "converted rect stays within screen 2 bounds")

        print("Test: single-display / cursor-not-over-any-dock falls back to first")
        let fallback = DockHoverGeometry.dockFrame(under: CGPoint(x: 5000, y: 5000), candidates: candidates)
        check(fallback == dock1, "no-cursor-match falls back to first dock")
        check(DockHoverGeometry.dockFrame(under: .zero, candidates: []) == nil, "no docks -> nil")

        print("Test: coordinate conversion flips Y (top-left -> bottom-left)")
        let c = DockHoverGeometry.convertToScreen(CGRect(x: 1000, y: 10, width: 60, height: 60), dockFrame: dock2)
        check(c.minX == 2920, "x = dockFrame.minX + frame.minX (\(c.minX))")
        check(c.minY == dock2.maxY - 70, "y = dockFrame.maxY - frame.maxY (\(c.minY))")

        if failures == 0 { print("\nALL PASSED ✅"); exit(0) }
        else { print("\n\(failures) FAILURE(S) ❌"); exit(1) }
    }
}
