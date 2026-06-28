//
//  WindowMoveGeometry.swift
//  Docky
//
//  Pure geometry for "move this window onto that screen": given a window's
//  current frame and the source/destination screen rects (all in NSScreen
//  bottom-left space), computes where the window should land — preserving size
//  (clamped to the destination) and proportional position, clamped so the window
//  stays fully inside the destination's visible area. No AppKit dependency so it
//  can be unit-tested standalone (see Tests/standalone/WindowMoveGeometryTests.swift).
//

import CoreGraphics

enum WindowMoveGeometry {
    /// Destination frame for moving a window from the `from` screen to the `to`
    /// screen, like Hammerspoon's `window:moveToScreen`.
    ///
    /// - Parameters:
    ///   - windowFrame: the window's current frame (NSScreen / bottom-left space).
    ///   - from: the source screen's full frame.
    ///   - to: the destination screen's full frame.
    ///   - visible: the destination screen's visible frame (menu bar / Dock
    ///     excluded); the result is clamped to fit inside this.
    /// - Returns: the new frame. Size is the original clamped to `visible`; the
    ///   origin keeps the window at the same proportional position it had on
    ///   `from`, then clamped so the window stays fully on the destination screen.
    static func targetFrame(
        windowFrame: CGRect,
        from: CGRect,
        to: CGRect,
        visible: CGRect
    ) -> CGRect {
        let width = min(windowFrame.width, visible.width)
        let height = min(windowFrame.height, visible.height)

        // Position relative to the source screen, 0...1 along each axis.
        let relativeX = from.width > 0 ? (windowFrame.minX - from.minX) / from.width : 0
        let relativeY = from.height > 0 ? (windowFrame.minY - from.minY) / from.height : 0

        // The same proportional spot on the destination, clamped to the visible
        // area so the window can't land under the menu bar or off-screen.
        let maxX = max(visible.minX, visible.maxX - width)
        let maxY = max(visible.minY, visible.maxY - height)
        let originX = min(max(to.minX + relativeX * to.width, visible.minX), maxX)
        let originY = min(max(to.minY + relativeY * to.height, visible.minY), maxY)

        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
