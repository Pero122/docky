# Dock Drag-Resize — Design Spec

**Date:** 2026-06-28
**Status:** ✅ Design approved (verbally) — ready for implementation plan
**Feature branch:** `feat/dock-drag-resize` (off the crash-fix branch — the dock must launch for this to be testable)

## Goal

Let the user resize the dock by **dragging its separator line(s) or top edge** — direct
manipulation, mirroring the native macOS Dock (where you drag the divider to resize).
Today the only way to change size is the Settings slider; dragging the dock does nothing.

## Approved decisions

1. **Resize target = icon/tile size** (the existing `tileSize`), not background padding.
2. **Scope = global for v1** — dragging any dock resizes *all* docks, and the Settings slider
   stays in sync. Per-screen *independent* sizes = deferred follow-up (the bigger parked feature).
3. **Live resize while dragging** (real-time re-layout), persist on release.

## UX

- **Hit regions:** the separator line(s) between dock groups **and** the dock's top edge.
  Hovering shows the `resizeUpDown` cursor so the affordance is discoverable.
- **Gesture:** vertical drag. **Up = larger**, **down = smaller**. Horizontal movement ignored.
- **Mapping:** `newTileSize = clamp(startTileSize + (-dragDeltaY) * k, min, max)`, with `k`
  tuned so a comfortable drag covers the full range. Reuse the existing `tileSize` min/max.
- **Feedback:** the dock re-lays out live on each drag step.

## Architecture

- **Gesture owner:** a drag-tracking handler in the dock's AppKit view layer
  (`MainWindow` / `TileContainerView`). `mouseDown` in a hit region → enter resize tracking;
  `mouseDragged` → compute new tile size → apply live; `mouseUp` → persist.
- **Apply live:** push the in-progress `tileSize` into layout (`TileContainerView` already reads
  `tileSize` for sizing) and trigger a re-layout — *without* persisting every frame.
- **Persist:** on `mouseUp`, call `DockSettingsService.setTileSize(...)` (already persists +
  emits the pref-change notification). All per-screen docks + the slider update via the existing
  settings-change → re-layout path — which is why **global scope is essentially free**.

## Pure logic to isolate + unit-test

Extract the mapping into a pure function (no AppKit), mirroring the preview-fix pattern:

```
DockResizeGeometry.tileSize(forDragDeltaY:startTileSize:bounds:) -> CGFloat
```

Standalone `@main` swiftc test (Docky has no XCTest target) covering: drag up grows, drag down
shrinks, clamps at min and max, zero delta is a no-op. Red → green before wiring the gesture.

## Testing

- **Unit:** the `DockResizeGeometry` mapping (standalone test, like `DockHoverGeometryTests`).
- **GUI self-test via "touchMyPc" (Peekaboo):** grab a dock separator, drag up → icons grow,
  drag down → shrink, release → size persists (verify via the persisted `tileSize` / Settings).

## Out of scope (YAGNI)

- Per-screen *independent* sizes (separate follow-up feature).
- Drag-reorder, magnification changes, horizontal/length resize.

## Risks / unknowns (resolve during implementation)

- Exact separator view + its hit area in the current `TileContainerView` layout.
- Whether live `tileSize` updates can apply without a full tile rebuild (perf) — throttle the
  re-layout if a full rebuild per drag-step is too costly.
- Cursor-rect / tracking-area management for the hit regions.
