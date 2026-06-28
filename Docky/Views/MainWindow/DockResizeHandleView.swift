//
//  DockResizeHandleView.swift
//  Docky
//
//  Transparent overlay that sits ABOVE the SwiftUI dock content. It claims only
//  the thin resize-handle strips along the dock's outer border and its two side
//  ends, so:
//   - the resize cursor shows on hover (mouse-tracking → NSCursor.set; the window
//     is flagged for background cursor authority so it paints while inactive),
//   - dragging a strip resizes the dock (DockResizeGeometry → setTileSize, live),
//   - every other point falls through to the SwiftUI tiles below (hitTest → nil).
//
//  Living above the hosting view keeps its drags from being swallowed by the
//  SwiftUI hosting view below.
//

import AppKit
import Combine

final class DockResizeHandleView: NSView {
    /// Grab tolerance around each handle strip, in points.
    private let grab: CGFloat = 14
    /// Tile-size range — matches the Appearance settings slider (16...128 pt).
    private let tileSizeBounds: ClosedRange<CGFloat> = 16...128
    /// Active drag: pointer location (window coords) + tile size at drag start.
    private var resizeStart: (location: NSPoint, tileSize: CGFloat)?
    private var chromeObserver: AnyCancellable?
    /// One cursor tracking area per handle strip. Rebuilt whenever the chrome
    /// size changes (the strips move) or AppKit re-lays-out the view.
    private var handleTrackingAreas: [NSTrackingArea] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        observeChrome()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeChrome()
    }

    /// The handle strips move when the chrome size changes (live during a drag,
    /// or when the size is changed from Settings), so rebuild the cursor
    /// tracking areas to match.
    private func observeChrome() {
        chromeObserver = DockLayoutService.shared.$chromeSize
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildHandleTrackingAreas()
            }
    }

    // MARK: - Hit-testing & cursor

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return handleRects().contains(where: { $0.contains(local) }) ? self : nil
    }

    /// Resize even when the panel isn't key (it's a non-activating panel).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Mouse-tracking (enter/move/exit) drives the cursor, via `NSTrackingArea`s
    /// with `.activeAlways` so events fire even though the dock never becomes key
    /// (cursor rects and `cursorUpdate(with:)` are key-window-gated and never fire
    /// here — verified empirically). The `NSCursor.set()` only *paints* over the
    /// inactive panel because `MainWindow` flags the window for background cursor
    /// authority (`SetsCursorInBackground` connection property + the
    /// `SLSSetWindowTags` `setsCursorInBackground` bit); without that flag the
    /// window server silently keeps the active app's arrow.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        rebuildHandleTrackingAreas()
    }

    private func rebuildHandleTrackingAreas() {
        for area in handleTrackingAreas {
            removeTrackingArea(area)
        }
        handleTrackingAreas = handleRects().map { rect in
            NSTrackingArea(
                rect: rect,
                options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
                owner: self,
                userInfo: nil
            )
        }
        for area in handleTrackingAreas {
            addTrackingArea(area)
        }
    }

    /// Sets the resize cursor. With the window flagged for background cursor
    /// authority (see `updateTrackingAreas`), `NSCursor.set()` paints over the
    /// inactive dock. Re-asserted on every `mouseMoved` because the window server
    /// can reset the cursor on its own activity; restored to the arrow once the
    /// pointer leaves all strips. (All strips show ↕ for a bottom/top dock since
    /// it resizes on the vertical drag; ↔ for a left/right dock.)
    private func setResizeCursor() {
        (isVerticalResize ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).set()
    }

    override func mouseEntered(with event: NSEvent) { setResizeCursor() }
    override func mouseMoved(with event: NSEvent) { setResizeCursor() }
    override func mouseExited(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if !handleRects().contains(where: { $0.contains(local) }) {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Drag

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        guard handleRects().contains(where: { $0.contains(local) }) else { return }
        resizeStart = (location: event.locationInWindow,
                       tileSize: DockSettingsService.shared.displayTileSize)
        setResizeCursor()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = resizeStart else { return }
        let newSize = DockResizeGeometry.tileSize(
            forDragDeltaY: growDelta(from: start.location, to: event.locationInWindow),
            startTileSize: start.tileSize,
            bounds: tileSizeBounds
        )
        DockSettingsService.shared.setTileSize(newSize)
        setResizeCursor()
    }

    override func mouseUp(with event: NSEvent) {
        resizeStart = nil // setTileSize already persisted the size live
        let local = convert(event.locationInWindow, from: nil)
        if !handleRects().contains(where: { $0.contains(local) }) {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Geometry

    private var isVerticalResize: Bool {
        switch DockyPreferences.shared.windowPosition
            .resolved(systemOrientation: DockSettingsService.shared.orientation) {
        case .bottom, .top: return true
        case .left, .right: return false
        }
    }

    /// The chrome rectangle in this view's (bottom-left) coordinate space,
    /// assuming the chrome is centred on its cross-axis and flush to the screen
    /// edge along its main axis.
    private func chromeRect() -> NSRect? {
        let cs = DockLayoutService.shared.chromeSize
        guard cs.width > 0, cs.height > 0, bounds.width > 0, bounds.height > 0 else { return nil }
        let W = bounds.width, H = bounds.height
        let cw = min(cs.width, W), ch = min(cs.height, H)
        switch DockyPreferences.shared.windowPosition
            .resolved(systemOrientation: DockSettingsService.shared.orientation) {
        case .bottom: return NSRect(x: (W - cw) / 2, y: 0,          width: cw, height: ch)
        case .top:    return NSRect(x: (W - cw) / 2, y: H - ch,     width: cw, height: ch)
        case .left:   return NSRect(x: 0,            y: (H - ch) / 2, width: cw, height: ch)
        case .right:  return NSRect(x: W - cw,       y: (H - ch) / 2, width: cw, height: ch)
        }
    }

    /// Resize-grab strips: the outer border (the chrome edge furthest from the
    /// screen) plus the two perpendicular "side" ends.
    private func handleRects() -> [NSRect] {
        guard let chrome = chromeRect() else { return [] }
        let t = grab
        let outer: NSRect
        let sideA: NSRect
        let sideB: NSRect
        switch DockyPreferences.shared.windowPosition
            .resolved(systemOrientation: DockSettingsService.shared.orientation) {
        case .bottom:
            outer = NSRect(x: chrome.minX, y: chrome.maxY - t, width: chrome.width, height: 2 * t)
            sideA = NSRect(x: chrome.minX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
            sideB = NSRect(x: chrome.maxX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
        case .top:
            outer = NSRect(x: chrome.minX, y: chrome.minY - t, width: chrome.width, height: 2 * t)
            sideA = NSRect(x: chrome.minX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
            sideB = NSRect(x: chrome.maxX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
        case .left:
            outer = NSRect(x: chrome.maxX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
            sideA = NSRect(x: chrome.minX, y: chrome.maxY - t, width: chrome.width, height: 2 * t)
            sideB = NSRect(x: chrome.minX, y: chrome.minY - t, width: chrome.width, height: 2 * t)
        case .right:
            outer = NSRect(x: chrome.minX - t, y: chrome.minY, width: 2 * t, height: chrome.height)
            sideA = NSRect(x: chrome.minX, y: chrome.maxY - t, width: chrome.width, height: 2 * t)
            sideB = NSRect(x: chrome.minX, y: chrome.minY - t, width: chrome.width, height: 2 * t)
        }
        return [outer, sideA, sideB]
    }

    /// Signed "grow" delta for the current dock position: positive when the drag
    /// moves the outer edge away from the screen (= a bigger dock).
    private func growDelta(from start: NSPoint, to current: NSPoint) -> CGFloat {
        switch DockyPreferences.shared.windowPosition
            .resolved(systemOrientation: DockSettingsService.shared.orientation) {
        case .bottom: return current.y - start.y   // drag up grows
        case .top:    return start.y - current.y   // drag down grows
        case .left:   return current.x - start.x   // drag right grows
        case .right:  return start.x - current.x   // drag left grows
        }
    }
}
