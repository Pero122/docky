//
//  DockSectionModelTests.swift
//  Docky — standalone tests for DockSectionModel (modular dock-groups engine).
//
//  Compiled with Docky/Services/DockSectionModel.swift via Tests/standalone/run.sh.
//

import Foundation

private var failures = 0

private func check(_ condition: Bool, _ message: String) {
    if condition {
        print("  ✓ \(message)")
    } else {
        failures += 1
        print("  ✗ \(message)")
    }
}

/// A representative 3-group dock: pinned | running | trailing.
private func sampleSections() -> [DockSection] {
    [
        DockSection(id: "pinned", tags: [.defaultPin], leadingDividerID: nil, tileIDs: ["pinned:A", "pinned:B"]),
        DockSection(id: "running", tags: [.absorbsRunningUnpinned], leadingDividerID: "divider:running", tileIDs: ["running:X"]),
        DockSection(id: "trailing", tags: [.trailing], leadingDividerID: "divider:trailing", tileIDs: ["trash"]),
    ]
}

@main
enum DockSectionModelTests {
    static func main() {
        // 1. Default placement routes a new item to the section with the matching tag.
        let s = sampleSections()
        check(DockSectionArrangement.defaultSectionID(for: .pinnedApp, in: s) == "pinned", "pinnedApp → pinned section")
        check(DockSectionArrangement.defaultSectionID(for: .runningUnpinned, in: s) == "running", "runningUnpinned → running section")
        check(DockSectionArrangement.defaultSectionID(for: .trailingItem, in: s) == "trailing", "trailingItem → trailing section")

        // 2. placeNewTile appends to the default section.
        let placed = DockSectionArrangement.placeNewTile("pinned:C", kind: .pinnedApp, in: s)
        check(placed.first(where: { $0.id == "pinned" })?.tileIDs == ["pinned:A", "pinned:B", "pinned:C"], "new pin appends to pinned")

        // 3. placeNewTile is a no-op when the tile already exists anywhere.
        let dup = DockSectionArrangement.placeNewTile("running:X", kind: .runningUnpinned, in: s)
        check(dup == s, "placing an already-present tile is a no-op")

        // 4. move: any tile to any section (drag anywhere) — removes from old, inserts at index.
        let moved = DockSectionArrangement.move(tileID: "pinned:A", toSectionID: "running", atIndex: 1, in: s)
        check(moved.first(where: { $0.id == "pinned" })?.tileIDs == ["pinned:B"], "moved tile leaves its old section")
        check(moved.first(where: { $0.id == "running" })?.tileIDs == ["running:X", "pinned:A"], "moved tile inserts at the target index")

        // 5. move clamps an out-of-range index to the section's end.
        let clamped = DockSectionArrangement.move(tileID: "trash", toSectionID: "pinned", atIndex: 99, in: s)
        check(clamped.first(where: { $0.id == "pinned" })?.tileIDs == ["pinned:A", "pinned:B", "trash"], "out-of-range index clamps to end")
        check(clamped.first(where: { $0.id == "trailing" })?.tileIDs == [], "moved trailing item leaves trailing empty")

        // 6. move to a non-existent section is a no-op.
        let noop = DockSectionArrangement.move(tileID: "pinned:A", toSectionID: "nope", atIndex: 0, in: s)
        check(noop == s, "move to unknown section is a no-op")

        // 7. assemble flattens with dividers between non-empty sections.
        check(
            DockSectionArrangement.assemble(s) == ["pinned:A", "pinned:B", "divider:running", "running:X", "divider:trailing", "trash"],
            "assemble interleaves dividers between non-empty groups"
        )

        // 8a. An empty middle group emits no divider.
        var noRunning = s
        noRunning[1].tileIDs = []
        check(
            DockSectionArrangement.assemble(noRunning) == ["pinned:A", "pinned:B", "divider:trailing", "trash"],
            "empty running group drops its divider"
        )

        // 8b. The first non-empty group never gets a leading divider.
        var onlyRunningTrailing = s
        onlyRunningTrailing[0].tileIDs = []
        check(
            DockSectionArrangement.assemble(onlyRunningTrailing) == ["running:X", "divider:trailing", "trash"],
            "leading group emits no divider even when it carries one"
        )

        if failures == 0 {
            print("DockSectionModelTests: all passed ✅")
        } else {
            print("DockSectionModelTests: \(failures) FAILED ❌")
            exit(1)
        }
    }
}
