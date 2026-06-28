//
//  RunningTileOrderTests.swift
//  Docky — standalone tests
//
//  Docky has no XCTest target, so pure-logic regression tests live here and run
//  via `Tests/standalone/run.sh` (compiles the real source file together with the
//  test using `swiftc`). See Tests/README.md.
//
//  Covers the running (middle) group ordering: arrange by saved order, remember
//  newly-seen bundles, and apply a drag reorder while preserving the remembered
//  slot of bundles that have quit.
//

import Foundation

@main
enum RunningTileOrderTests {
    static var failures = 0

    static func check(_ cond: Bool, _ msg: String) {
        if cond { print("  ✅ \(msg)") }
        else { print("  ❌ \(msg)"); failures += 1 }
    }

    static func main() {
        // arrange: saved order is respected, new bundles append in launch order.
        print("Test: arrange keeps saved order and appends new bundles")
        let a1 = RunningTileOrder.arrange(running: ["C", "A", "B"], saved: ["A", "B"])
        check(a1 == ["A", "B", "C"], "saved [A,B] first, new C appended (got \(a1))")

        // arrange: a saved-but-not-running (quit) bundle is simply absent.
        print("Test: arrange drops saved bundles that aren't currently running")
        let a2 = RunningTileOrder.arrange(running: ["A", "C"], saved: ["A", "B", "C"])
        check(a2 == ["A", "C"], "B not running so omitted, order preserved (got \(a2))")

        // remember: new running bundles get appended to the saved order.
        print("Test: remember appends newly-seen running bundles")
        let r1 = RunningTileOrder.remember(running: ["A", "B", "C"], saved: ["A"])
        check(r1 == ["A", "B", "C"], "B,C appended to saved (got \(r1))")

        // remember: a quit bundle stays remembered; nothing new => unchanged.
        print("Test: remember keeps quit bundles and is a no-op when nothing is new")
        let r2 = RunningTileOrder.remember(running: ["A"], saved: ["A", "B", "C"])
        check(r2 == ["A", "B", "C"], "B,C remembered though not running (got \(r2))")

        // applyReorder: a plain swap of two running bundles.
        print("Test: applyReorder swaps running bundles")
        let p1 = RunningTileOrder.applyReorder(newRunningOrder: ["B", "A"], saved: ["A", "B"])
        check(p1 == ["B", "A"], "A,B -> B,A (got \(p1))")

        // applyReorder: a quit bundle (B) keeps its remembered slot between others.
        print("Test: applyReorder preserves the slot of a quit bundle")
        let p2 = RunningTileOrder.applyReorder(newRunningOrder: ["C", "A"], saved: ["A", "B", "C"])
        check(p2 == ["C", "B", "A"], "running C,A reorders around quit B in the middle (got \(p2))")

        // applyReorder: a new app dragged into the middle lands where dropped.
        print("Test: applyReorder inserts a newly-arranged bundle at its drop spot")
        let p3 = RunningTileOrder.applyReorder(newRunningOrder: ["A", "X", "B"], saved: ["A", "B"])
        check(p3 == ["A", "X", "B"], "X inserted between A and B (got \(p3))")

        if failures == 0 { print("\nALL PASSED ✅"); exit(0) }
        else { print("\n\(failures) FAILURE(S) ❌"); exit(1) }
    }
}
