//
//  AppUpdateService.swift
//  Docky
//

import Combine
import Foundation
import Sparkle

private final class AppUpdateFeedDelegate: NSObject, SPUUpdaterDelegate {
    let fallbackFeedURLString: String

    init(fallbackFeedURLString: String) {
        self.fallbackFeedURLString = fallbackFeedURLString
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        if let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
           !feedURL.isEmpty {
            return feedURL
        }

        return fallbackFeedURLString
    }
}

final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    static let feedURLString = "https://getdocky.com/releases/appcast.xml"

    @Published private(set) var canCheckForUpdates: Bool
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            guard automaticallyChecksForUpdates != oldValue else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            guard automaticallyDownloadsUpdates != oldValue else { return }
            updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    @Published var updateCheckInterval: TimeInterval {
        didSet {
            guard updateCheckInterval != oldValue else { return }
            updater.updateCheckInterval = updateCheckInterval
        }
    }

    let updaterController: SPUStandardUpdaterController
    private let feedDelegate: AppUpdateFeedDelegate

    private var updater: SPUUpdater {
        updaterController.updater
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        feedDelegate = AppUpdateFeedDelegate(fallbackFeedURLString: Self.feedURLString)

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: feedDelegate,
            userDriverDelegate: nil
        )

        let updater = updaterController.updater

        // FORK SAFETY — never auto-update. The bundled appcast (`SUFeedURL`) still
        // points at upstream getdocky.com, so a background update would silently
        // replace this fork with the official build (wiping the multi-screen /
        // drag-resize / widget-security changes). Force auto-check + auto-download
        // off at the source on every launch, so neither Sparkle's first-run prompt
        // nor a stray `defaults write gt.quintero.Docky SUEnableAutomaticChecks`
        // can re-arm the background path. The manual "Check for Updates…" menu item
        // still works for deliberate, user-initiated checks.
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false

        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        updateCheckInterval = updater.updateCheckInterval

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheckForUpdates in
                self?.canCheckForUpdates = canCheckForUpdates
            }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] automaticallyChecksForUpdates in
                self?.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] automaticallyDownloadsUpdates in
                self?.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            }
            .store(in: &cancellables)

        updater.publisher(for: \.updateCheckInterval)
            .receive(on: RunLoop.main)
            .sink { [weak self] updateCheckInterval in
                self?.updateCheckInterval = updateCheckInterval
            }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        guard automaticallyChecksForUpdates, canCheckForUpdates else { return }
        updater.checkForUpdatesInBackground()
    }
}
