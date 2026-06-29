//
//  AppUpdateService.swift
//  Docky
//

import Combine
import Foundation
import Sparkle

/// Permanently disables Sparkle auto-update in this fork.
///
/// The bundled appcast (`SUFeedURL`) points at upstream getdocky.com and updates
/// are signed with upstream's key, so *any* update — automatic OR a manual
/// "Check for Updates…" — would replace this fork with the official build and
/// wipe its changes (multi-screen, drag-resize, widget hardening, …).
///
/// This delegate makes that impossible rather than merely "off by default":
///  - `feedURLString` returns `nil` → there is no URL to pull from.
///  - `mayPerformUpdateCheck` throws → every check (manual, scheduled, background)
///    is vetoed at the source, before any network request, even if a user flips
///    `SUEnableAutomaticChecks` via `defaults write` or clicks the menu item.
///  - `shouldProceedWithUpdate` throws → a final refusal in case an appcast item
///    ever reached that far.
private final class AppUpdateFeedDelegate: NSObject, SPUUpdaterDelegate {
    private static func lockError(_ code: Int) -> NSError {
        NSError(
            domain: "gt.quintero.Docky.ForkUpdateLock",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: "Software updates are disabled in this fork of Docky."]
        )
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        nil
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        throw Self.lockError(1)
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        throw Self.lockError(2)
    }
}

final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    /// Always `false` in this fork. Existing UI (the "Check for Updates…" menu
    /// item and Settings button) binds to this, so both stay greyed out.
    @Published private(set) var canCheckForUpdates = false

    let updaterController: SPUStandardUpdaterController
    private let feedDelegate = AppUpdateFeedDelegate()

    private var updater: SPUUpdater {
        updaterController.updater
    }

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: feedDelegate,
            userDriverDelegate: nil
        )

        let updater = updaterController.updater
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false
    }

    /// No-op: the fork never checks for updates. Kept so existing callers compile.
    /// (Even if this called through, `AppUpdateFeedDelegate` vetoes the check.)
    func checkForUpdates() {}

    /// No-op for the same reason — see `checkForUpdates()`.
    func checkForUpdatesInBackground() {}
}
