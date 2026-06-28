//
//  RunningTileOrder.swift
//  Docky
//
//  Pure ordering logic for the running (unpinned) app group, so it can be
//  drag-reordered and persist like the pinned/trailing groups. Kept free of any
//  app/AppKit types so it can be unit-tested standalone (see
//  Tests/standalone/RunningTileOrderTests.swift).
//
//  The saved order is a list of bundle identifiers. A bundle keeps its
//  remembered slot even after it quits, so when it relaunches it returns to the
//  same place ("remember its slot"). Bundles never seen before append at the end.
//

enum RunningTileOrder {
    /// Arranges the currently-running bundles for display: bundles present in
    /// `saved` come first in saved order; bundles not in `saved` append after,
    /// in their original (launch) order.
    static func arrange(running: [String], saved: [String]) -> [String] {
        let runningSet = Set(running)
        let savedSet = Set(saved)
        let savedPart = saved.filter { runningSet.contains($0) }
        let appended = running.filter { !savedSet.contains($0) }
        return savedPart + appended
    }

    /// The saved order updated to include any newly-seen running bundles
    /// (appended at the end). Bundles that have quit keep their remembered slot
    /// (they are never removed here). Returns `saved` unchanged when nothing is
    /// new, so callers can skip a redundant write.
    static func remember(running: [String], saved: [String]) -> [String] {
        let savedSet = Set(saved)
        let appended = running.filter { !savedSet.contains($0) }
        return appended.isEmpty ? saved : saved + appended
    }

    /// Applies a drag reorder of the currently-running bundles to the saved
    /// order. The running bundles are placed in `newRunningOrder`'s order, while
    /// bundles that have quit (present in `saved` but not running) keep their
    /// absolute slot — so a remembered, currently-quit app stays between the same
    /// neighbours. Running bundles not yet in `saved` append at the end.
    static func applyReorder(newRunningOrder: [String], saved: [String]) -> [String] {
        let runningSet = Set(newRunningOrder)
        var queue = newRunningOrder
        var result: [String] = []
        for bundle in saved {
            if runningSet.contains(bundle) {
                if !queue.isEmpty { result.append(queue.removeFirst()) }
                // A running bundle already consumed (duplicate in saved) is dropped.
            } else {
                result.append(bundle) // quit/remembered bundle keeps its slot
            }
        }
        result.append(contentsOf: queue) // running bundles not previously saved
        return result
    }
}
