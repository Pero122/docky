# All-Displays Dock Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `.allDisplays` mode to docky so a dock appears on **every** connected monitor simultaneously (one dock per screen), instead of only on the primary display or the display containing the pointer.

**Architecture:** docky uses a single `MainWindow` (`NSPanel`, loaded from `MainWindow.xib`) owned by `AppDelegate.mainWindowController`; the window positions itself via `applyCurrentFrame()` reading `targetScreen()`. We add (a) an `.allDisplays` enum case, (b) an `assignedScreen` on `MainWindow` so an instance can be *pinned* to one screen, and (c) a controller-set in `AppDelegate` that creates one `MainWindow` per `NSScreen.screens` entry when `.allDisplays` is selected, rebuilding on display hot-plug. Single-dock modes are unchanged.

**Tech Stack:** Swift, AppKit (`NSPanel`, `NSScreen`, `NSWindowController`), SwiftUI (settings), Combine (observers), `CGDirectDisplayID` for stable screen identity.

## Global Constraints

- **Build tool:** Xcode project `Docky.xcodeproj`, scheme `Docky`. Build/run via Xcode (Cmd-R) or `xcodebuild -project Docky.xcodeproj -scheme Docky -configuration Debug build`.
- **Platform:** macOS 14+ (Apple silicon). Verification machine has 3 displays.
- **No unit tests exist; this is GUI work.** Each task's "verify" step is **build + run + observe on the real displays**, not xctest. Keep changes minimal and observable.
- **Branch:** Work on `feat/all-displays`, based off `harden/strip-widgets` (so the widget-hardening security fix is included). Frequent commits, one per task.
- **Do not regress single-dock modes.** `.primaryDisplay` and `.displayContainingPointer` must behave exactly as before.
- **Preserve existing naming:** preference property `windowDisplayTarget`, key `"docky.windowDisplayTarget"`, controller property `mainWindowController`.

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `Docky/Services/DockyPreferences.swift` | `DockWindowDisplayTarget` enum + storage | Add `.allDisplays` case + title |
| `Docky/Views/MainWindow/MainWindow.swift` | The dock panel; positioning; `targetScreen()` | Add `assignedScreen`; honor it in `targetScreen()`; add `NSScreen.displayID` helper |
| `Docky/AppDelegate.swift` | Owns dock window(s); lifecycle | Multi-controller management + `syncDockWindowsToScreens()` + wiring |
| `Docky/Views/SettingsWindow/BehaviorSettingsView.swift` | Display-target Picker + help text | Help text update (picker auto-includes new case via `allCases`) |
| `Docky/Services/WindowReservationService.swift` | Reserve screen-edge space vs maximized windows | (Polish) operate per-dock instead of `.first` |

---

## Task 1: Add the `.allDisplays` enum case (compiles, behaves like primary)

**Files:**
- Modify: `Docky/Services/DockyPreferences.swift:438-450`
- Modify: `Docky/Views/MainWindow/MainWindow.swift:972-983` (the `targetScreen()` switch — adding an enum case makes this switch non-exhaustive → compile error, so it must be handled here)
- Modify: `Docky/Views/SettingsWindow/BehaviorSettingsView.swift:121` (help text)

**Interfaces:**
- Produces: `DockWindowDisplayTarget.allDisplays` (new case, raw value `"allDisplays"`, title `"All Displays"`). Later tasks branch on this case.

- [ ] **Step 1: Add the enum case + title**

In `Docky/Services/DockyPreferences.swift`, change the enum (lines 438-450) to:

```swift
enum DockWindowDisplayTarget: String, CaseIterable, Identifiable {
    case primaryDisplay
    case displayContainingPointer
    case allDisplays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primaryDisplay: String(localized: "Primary Display")
        case .displayContainingPointer: String(localized: "Display With Pointer")
        case .allDisplays: String(localized: "All Displays")
        }
    }
}
```

- [ ] **Step 2: Make `targetScreen()` exhaustive (placeholder = primary)**

In `Docky/Views/MainWindow/MainWindow.swift`, the `targetScreen()` switch (lines 972-983) is now non-exhaustive. Add the `.allDisplays` case so it compiles. For this task it returns the primary screen (real per-screen pinning comes in Task 2):

```swift
private func targetScreen() -> NSScreen? {
    switch preferences.windowDisplayTarget {
    case .primaryDisplay:
        return NSScreen.screens.first ?? NSScreen.main
    case .displayContainingPointer:
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
    case .allDisplays:
        // Placeholder until Task 2 introduces per-window `assignedScreen`.
        return NSScreen.screens.first ?? NSScreen.main
    }
}
```

- [ ] **Step 3: Update the settings help text**

In `Docky/Views/SettingsWindow/BehaviorSettingsView.swift`, the help `Text` (line ~121) currently says "Docky uses a single main window...". Replace with:

```swift
    Text("Choose whether the dock stays on the primary display, follows the display containing the pointer, or appears on all displays at once.")
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
```

The Picker itself needs no change — it iterates `DockWindowDisplayTarget.allCases`, so "All Displays" appears automatically.

- [ ] **Step 4: Build + observe**

Build (Xcode Cmd-B, or `xcodebuild -project Docky.xcodeproj -scheme Docky -configuration Debug build`). Expected: **builds with no errors.** Run the app, open Settings → Behavior → Display. Expected: the Picker now lists **"All Displays"**. Selecting it shows a single dock on the primary display (placeholder behavior — correct for this task).

- [ ] **Step 5: Commit**

```bash
git add Docky/Services/DockyPreferences.swift Docky/Views/MainWindow/MainWindow.swift Docky/Views/SettingsWindow/BehaviorSettingsView.swift
git commit -m "feat(display): add All Displays target option (placeholder behavior)"
```

---

## Task 2: Pin a `MainWindow` to an `assignedScreen`

**Files:**
- Modify: `Docky/Views/MainWindow/MainWindow.swift` (add property + `NSScreen.displayID` helper + honor `assignedScreen` in `targetScreen()`)

**Interfaces:**
- Consumes: `DockWindowDisplayTarget.allDisplays` (Task 1).
- Produces:
  - `MainWindow.assignedScreen: NSScreen?` — when non-nil, this window renders on that exact screen.
  - `NSScreen.displayID: CGDirectDisplayID?` — stable display identity used by Task 3 to key windows.

- [ ] **Step 1: Add a stable screen-identity helper**

In `Docky/Views/MainWindow/MainWindow.swift`, add near the top (after imports, file scope):

```swift
extension NSScreen {
    /// Stable hardware identifier for a display. Unlike an `NSScreen`
    /// object (which is recreated on every display reconfiguration), this
    /// `CGDirectDisplayID` is stable for the life of the connection, so it
    /// is safe to key per-screen dock windows by it.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
```

- [ ] **Step 2: Add the `assignedScreen` property**

Inside `final class MainWindow: NSPanel`, add a stored property (near `static var allowsKeyWindow`):

```swift
    /// When non-nil, this dock instance is pinned to a specific display
    /// (used by `.allDisplays` mode, where AppDelegate creates one
    /// MainWindow per screen). When nil, screen selection falls back to
    /// the `windowDisplayTarget` preference (primary / pointer-following).
    var assignedScreen: NSScreen?
```

- [ ] **Step 3: Honor `assignedScreen` in `targetScreen()`**

Update `targetScreen()` so a pinned window always resolves to its assigned screen, regardless of the global preference:

```swift
private func targetScreen() -> NSScreen? {
    // A pinned instance (.allDisplays mode) always renders on its screen.
    if let assignedScreen { return assignedScreen }

    switch preferences.windowDisplayTarget {
    case .primaryDisplay:
        return NSScreen.screens.first ?? NSScreen.main
    case .displayContainingPointer:
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
    case .allDisplays:
        // Unpinned instance under .allDisplays (shouldn't normally happen —
        // AppDelegate pins every .allDisplays window) → default to primary.
        return NSScreen.screens.first ?? NSScreen.main
    }
}
```

- [ ] **Step 4: Build + observe (no behavior change expected)**

Build + run. `assignedScreen` is `nil` everywhere so far, so behavior is identical to Task 1: single dock, all three display modes work as before. Expected: **builds; no visible change.** This task is pure enabling infrastructure.

- [ ] **Step 5: Commit**

```bash
git add Docky/Views/MainWindow/MainWindow.swift
git commit -m "feat(display): pin MainWindow to an assignedScreen + stable displayID"
```

---

## Task 3: One dock per screen in `.allDisplays` mode

**Files:**
- Modify: `Docky/AppDelegate.swift` (line 19 property; `showMainWindow()` 347-352; add `syncDockWindowsToScreens()`)

**Interfaces:**
- Consumes: `MainWindow.assignedScreen`, `NSScreen.displayID` (Task 2); `makeMainWindowController()` (existing, AppDelegate.swift:354-370); `DockWindowDisplayTarget.allDisplays` (Task 1).
- Produces: `AppDelegate.syncDockWindowsToScreens()` — reconciles live dock windows to `NSScreen.screens` per the current `windowDisplayTarget`. Task 4 calls it from observers.

- [ ] **Step 1: Add the per-screen controller store**

In `Docky/AppDelegate.swift`, next to the existing `mainWindowController` property (line 19), add:

```swift
    /// `.allDisplays` mode: one dock controller per screen, keyed by stable
    /// display ID. Empty in single-dock modes. The existing
    /// `mainWindowController` remains the single-dock instance.
    private var perScreenControllers: [CGDirectDisplayID: MainWindowController] = [:]
```

- [ ] **Step 2: Add `syncDockWindowsToScreens()`**

Add this method to `AppDelegate`:

```swift
    /// Reconcile live dock windows to the current display configuration and
    /// `windowDisplayTarget`. Idempotent — safe to call on launch, on
    /// `didChangeScreenParametersNotification`, and on preference change.
    func syncDockWindowsToScreens() {
        guard DockyPreferences.shared.windowDisplayTarget == .allDisplays else {
            // Single-dock mode: tear down per-screen docks, restore the one dock.
            for controller in perScreenControllers.values { controller.close() }
            perScreenControllers.removeAll()
            if mainWindowController == nil {
                mainWindowController = makeMainWindowController()
            }
            mainWindowController?.showWindow(self)
            return
        }

        // .allDisplays: ensure exactly one pinned dock per connected screen.
        var liveIDs = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            liveIDs.insert(id)

            if let existing = perScreenControllers[id] {
                // NSScreen objects are recreated on reconfig — refresh the pin.
                (existing.window as? MainWindow)?.assignedScreen = screen
            } else if let controller = makeMainWindowController() {
                (controller.window as? MainWindow)?.assignedScreen = screen
                controller.showWindow(self)
                perScreenControllers[id] = controller
            }
        }

        // Close docks for displays that were disconnected.
        for (id, controller) in perScreenControllers where !liveIDs.contains(id) {
            controller.close()
            perScreenControllers.removeValue(forKey: id)
        }

        // Hide the single-dock instance — per-screen docks cover every display.
        mainWindowController?.window?.orderOut(nil)
    }
```

- [ ] **Step 3: Route startup through the sync**

In `showMainWindow()` (lines 347-352), replace the unconditional single-window creation so startup respects `.allDisplays`:

```swift
private func showMainWindow() {
    syncDockWindowsToScreens()
    DockyPreferences.shared.enableOpenAtLoginOnFirstLaunchIfNeeded()
}
```

(`syncDockWindowsToScreens()` creates `mainWindowController` in single-dock mode, or the per-screen set in `.allDisplays` mode.)

- [ ] **Step 4: Build + observe — THE payoff**

Build + run. In Settings → Behavior → Display, select **"All Displays"**. Expected: **a dock appears on all 3 monitors at once.** Switch back to "Primary Display" → only the primary keeps a dock. Switch to "All Displays" again → 3 docks return.

> Note: switching the picker may require the wiring in Task 4 to re-sync live. If the docks don't update immediately on picker change yet, quit + relaunch with "All Displays" already selected to confirm the per-screen creation works. Task 4 makes it live.

- [ ] **Step 5: Commit**

```bash
git add Docky/AppDelegate.swift
git commit -m "feat(display): create one pinned dock per screen in All Displays mode"
```

---

## Task 4: Live updates — preference change + display hot-plug

**Files:**
- Modify: `Docky/AppDelegate.swift` (observe preference change + `didChangeScreenParametersNotification`; tear-down in `applicationWillTerminate` if present)

**Interfaces:**
- Consumes: `syncDockWindowsToScreens()` (Task 3).

- [ ] **Step 1: Re-sync on display configuration change**

In `AppDelegate` (in `applicationDidFinishLaunching()`, after `showMainWindow()` at line 63, or wherever observers are set up), register:

```swift
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncDockWindowsToScreens()
        }
```

- [ ] **Step 2: Re-sync when the user changes the Display preference**

`DockyPreferences.windowDisplayTarget` is a plain property writing to `UserDefaults` (key `"docky.windowDisplayTarget"`). Observe the default-change notification so flipping the picker rebuilds docks live. Add in the same observer-setup location:

```swift
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncDockWindowsToScreens()
        }
```

> If `UserDefaults.didChangeNotification` proves too chatty (fires for every preference), narrow it: cache the last `windowDisplayTarget` in an instance var and early-return from `syncDockWindowsToScreens()` if neither the target nor `NSScreen.screens.count` changed. Add that guard only if you observe churn.

- [ ] **Step 3: Build + observe — live switching + hot-plug**

Build + run. Test:
1. Flip Display picker between "All Displays" and "Primary Display" → docks appear/disappear **without relaunch**.
2. With "All Displays" active, **unplug a monitor** → its dock vanishes, others remain. **Replug** → its dock returns.
Expected: all transitions are clean, no orphaned/duplicate docks.

- [ ] **Step 4: Commit**

```bash
git add Docky/AppDelegate.swift
git commit -m "feat(display): rebuild docks live on display + preference changes"
```

---

## Task 5 (Polish): Per-dock window reservation

**Files:**
- Modify: `Docky/Services/WindowReservationService.swift:85-90` (`scan(windows:)`)

**Interfaces:**
- Consumes: `perScreenControllers` window set (Task 3) — but service reads `NSApp.windows`, so no direct dependency.

**Why:** `scan(windows:)` currently grabs `NSApp.windows.compactMap { $0 as? MainWindow }.first` — only the first dock reserves edge space. In `.allDisplays`, a maximized window on screen 2 won't make room for screen 2's dock.

- [ ] **Step 1: Iterate all dock windows, reserve per-screen**

Replace the single-dock guard in `scan(windows:)` (lines 85-90) so it processes each `MainWindow`:

```swift
    private func scan(windows: [AppWindow]) {
        let docks = NSApp.windows.compactMap { $0 as? MainWindow }
        guard !docks.isEmpty,
              let primaryScreenHeight = NSScreen.screens.first?.frame.height
        else { return }

        for dock in docks {
            guard let dockyScreen = dock.screen,
                  let dockyFrame = dock.currentReservationFrame
            else { continue }
            // ... existing per-dock reservation logic, scoped to windows whose
            // screenContaining(...) == dockyScreen, using dockyFrame + primaryScreenHeight.
        }
    }
```

(Preserve the existing body inside the loop, filtering candidate windows to those on `dockyScreen` via the existing `screenContaining(_:)` helper at line 149.)

- [ ] **Step 2: Build + observe**

Build + run with "All Displays" + `maximizedWindowBehavior == .resizeWindow`. Maximize a window on a non-primary screen. Expected: it shrinks to leave room for **that screen's** dock, not just the primary's.

- [ ] **Step 3: Commit**

```bash
git add Docky/Services/WindowReservationService.swift
git commit -m "feat(display): reserve edge space for every per-screen dock"
```

---

## Task 6 (Polish): Per-dock autohide / visibility

**Files:**
- Verify-first, then modify `Docky/Views/MainWindow/MainWindow.swift` only if needed.

**Why:** With autohide on, each per-screen dock should reveal when the pointer hits *its own* screen edge. Because each `MainWindow` manages its own `visibilityState` and reveal logic, this likely already works per-instance — confirm before changing anything.

- [ ] **Step 1: Build + observe current behavior**

Build + run with "All Displays" + autohide enabled. Move the pointer to the dock edge of each screen. Expected (hopefully, no code change): each screen's dock reveals/hides independently.

- [ ] **Step 2: Fix only if a dock fails to reveal on its own screen**

If a non-primary dock never reveals: its reveal trigger is likely keyed to the global pointer/primary screen. Scope the reveal check to `assignedScreen` (the edge-detection should compare the pointer against `targetScreen()?.frame`, which already returns `assignedScreen` after Task 2). Make the minimal change and re-observe.

- [ ] **Step 3: Commit (only if changed)**

```bash
git add Docky/Views/MainWindow/MainWindow.swift
git commit -m "fix(display): reveal each per-screen dock from its own edge"
```

---

## Self-Review

**Spec coverage:** Goal = dock on every monitor. Task 1 (option) → Task 2 (pin) → Task 3 (create per screen) → Task 4 (live + hot-plug) deliver the core. Tasks 5-6 cover the two integration seams (reservation, autohide) the architecture map flagged as single-dock. ✅

**Placeholder scan:** Task 1's `.allDisplays` returns primary as an explicit, documented placeholder, resolved in Task 2. Task 5 references "existing per-dock reservation logic" — that body already exists at the cited lines; the change is the loop wrapper. Task 6 is verify-first by design. No TODO/TBD left.

**Type consistency:** `assignedScreen: NSScreen?`, `displayID: CGDirectDisplayID?`, `perScreenControllers: [CGDirectDisplayID: MainWindowController]`, `syncDockWindowsToScreens()`, `makeMainWindowController()` (existing), `windowDisplayTarget` / `DockWindowDisplayTarget.allDisplays` — names consistent across all tasks. ✅

**Known risks to watch during execution:**
- `MainWindow.xib` loaded N times: confirm each `loadNibNamed` yields an independent window (expected). If the XIB shares state, switch to programmatic `MainWindow(contentRect:...)` construction.
- `MainWindow.allowsKeyWindow` is `static` (shared across instances) — fine for one focused search field at a time; revisit only if multi-dock keyboard focus misbehaves.
- Shared overlay singletons (Launchpad, window previews) anchor to a "source frame"/pointer screen — out of scope here; they should still appear near whichever dock was hovered. Note if they misbehave; do not fix in this plan.
