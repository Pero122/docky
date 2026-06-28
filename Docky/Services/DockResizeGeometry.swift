//
//  DockResizeGeometry.swift
//  Docky
//
//  Pure geometry for drag-to-resize: maps a vertical drag on the dock's
//  separator / top edge into a new tile size. No AppKit dependency so it can be
//  unit-tested standalone (see Tests/standalone/DockResizeGeometryTests.swift).
//

import Foundation

enum DockResizeGeometry {
    /// New tile size for a vertical resize drag.
    ///
    /// - Parameters:
    ///   - dragDeltaY: vertical drag distance where **positive = grow** (drag
    ///     the dock's top edge upward). The caller supplies the sign in this
    ///     convention.
    ///   - startTileSize: tile size when the drag began.
    ///   - gain: tile-size points changed per point of drag (default 1:1).
    ///   - bounds: allowed `[min, max]` tile size; the result is clamped to it.
    static func tileSize(forDragDeltaY dragDeltaY: CGFloat,
                         startTileSize: CGFloat,
                         gain: CGFloat = 1.0,
                         bounds: ClosedRange<CGFloat>) -> CGFloat {
        let raw = startTileSize + dragDeltaY * gain
        return min(max(raw, bounds.lowerBound), bounds.upperBound)
    }
}
