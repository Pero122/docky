//
//  DockHoverGeometry.swift
//  Docky
//
//  Pure geometry helpers for anchoring hover-driven overlays (window
//  previews, widget expansions) to the correct dock/screen on multi-display
//  setups.
//
//  Extracted as free functions with no AppKit-window dependency so the
//  multi-display selection math is unit-testable. The thin AppKit wrapper
//  that feeds these live `NSApp.windows` / `NSEvent.mouseLocation` values is
//  `MainWindow.dockUnderCursor()`.
//

import CoreGraphics

enum DockHoverGeometry {
    /// Picks the dock frame the cursor is currently over, falling back to the
    /// first candidate (single-dock setups, or a programmatic present where
    /// the cursor isn't over any dock). Returns nil only when there are no
    /// docks at all.
    ///
    /// In `.allDisplays` mode there is one dock per screen, so callers MUST
    /// resolve the dock the interaction originated from rather than blindly
    /// taking the first window — otherwise the overlay's coordinate
    /// conversion uses the wrong dock and renders on the wrong display.
    static func dockFrame(under cursor: CGPoint, candidates: [CGRect]) -> CGRect? {
        // Resolve the dock the cursor is currently over (one per screen in
        // `.allDisplays`); fall back to the first for single-display setups
        // or a programmatic present where the cursor isn't over any dock.
        return candidates.first { $0.contains(cursor) } ?? candidates.first
    }

    /// Converts a SwiftUI window-local rect (top-left origin, relative to the
    /// originating dock window's hosting view) into AppKit screen coordinates
    /// (bottom-left origin) using that dock's screen frame.
    static func convertToScreen(_ frame: CGRect, dockFrame: CGRect) -> CGRect {
        CGRect(
            x: dockFrame.minX + frame.minX,
            y: dockFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}
