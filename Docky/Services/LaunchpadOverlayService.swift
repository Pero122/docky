//
//  LaunchpadOverlayService.swift
//  Docky
//

import AppKit
import Combine
import CoreImage
import Foundation

/// What the launchpad grid shows: either an app at the top of /Applications,
/// or a subfolder of /Applications represented as a dock-style app folder
/// tile (e.g. /Applications/Utilities). The launchpad mirrors the
/// /Applications directory structure one level deep — anything inside a
/// subfolder is reached through the folder tile, not flattened into the top
/// level.
enum LaunchpadEntry: Identifiable {
    case app(AppTile)
    case folder(AppFolderTile)

    var id: String {
        switch self {
        case .app(let app): return "app:\(app.bundleIdentifier)"
        case .folder(let folder): return "folder:\(folder.identifier)"
        }
    }

    var displayName: String {
        switch self {
        case .app(let app): return app.displayName
        case .folder(let folder): return folder.displayName
        }
    }

    var matchableBundleIdentifier: String {
        switch self {
        case .app(let app): return app.bundleIdentifier
        case .folder: return ""
        }
    }
}

final class LaunchpadOverlayService: ObservableObject {
    static let shared = LaunchpadOverlayService()

    @Published private(set) var isPresented = false
    @Published private(set) var entries: [LaunchpadEntry] = []
    /// Wallpaper for the screen the overlay is currently presented on. Driven
    /// by the window controller before the overlay animates in so the view
    /// can render the desktop image as the launchpad's blurred background.
    @Published var wallpaperURL: URL?
    /// Average wallpaper luminance in [0, 1] (Rec. 709 weights). Recomputed
    /// asynchronously off-main whenever `wallpaperURL` changes so the view
    /// can flip its color scheme for legibility on light wallpapers.
    @Published private(set) var wallpaperLuminance: Double = 0

    /// Roots scanned for launchpad entries. `/Applications` holds user-
    /// installed apps; `/System/Applications` holds Apple-provided ones
    /// (Calculator, Notes, Reminders, etc.) — without it the launchpad
    /// would be missing every built-in app. `~/Applications` is rare but
    /// some installers put per-user apps there.
    private static let applicationDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    ]
    private let scanQueue = DispatchQueue(
        label: "gt.quintero.Docky.LaunchpadScan",
        qos: .utility
    )
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var pendingRescan: DispatchWorkItem?
    private var wallpaperLuminanceSubscription: AnyCancellable?
    private static let luminanceContext = CIContext(options: [.workingColorSpace: NSNull()])

    private init() {
        startWatchingApplicationDirectories()
        observeWallpaperURL()
        scheduleRescan(delay: 0)
    }

    func toggle() {
        isPresented ? dismiss() : present()
    }

    func present() {
        guard ProductService.shared.isUnlocked(.launchpad), DockyPreferences.shared.enablesLaunchpadOverlay else {
            dismiss()
            return
        }

        if entries.isEmpty {
            entries = Self.scanApplications()
        }
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    /// Recompute average wallpaper luminance whenever the URL changes.
    /// CIAreaAverage is GPU-accelerated and renders down to a 1×1 tile, so
    /// the work amortizes well — but the JPEG/HEIC decode in front of it
    /// can be tens of milliseconds, hence the user-initiated background
    /// queue and `switchToLatest` to drop in-flight work if the user flips
    /// to another screen mid-flight.
    private func observeWallpaperURL() {
        wallpaperLuminanceSubscription = $wallpaperURL
            .removeDuplicates()
            .map { url -> AnyPublisher<Double, Never> in
                guard let url else {
                    return Just(0).eraseToAnyPublisher()
                }
                return Future { promise in
                    DispatchQueue.global(qos: .userInitiated).async {
                        promise(.success(Self.computeAverageLuminance(of: url) ?? 0))
                    }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] luminance in
                self?.wallpaperLuminance = luminance
            }
    }

    private static func computeAverageLuminance(of url: URL) -> Double? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]),
              let output = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        Self.luminanceContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Rec. 709 perceived luminance on gamma-encoded sRGB. Good enough
        // for a colorScheme threshold; not worth a precise sRGB→linear
        // round-trip when we just need a light-vs-dark decision.
        let r = Double(bitmap[0]) / 255
        let g = Double(bitmap[1]) / 255
        let b = Double(bitmap[2]) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func startWatchingApplicationDirectories() {
        for directory in Self.applicationDirectories {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }

            let descriptor = open(directory.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .extend, .link],
                queue: DispatchQueue.main
            )
            source.setEventHandler { [weak self] in
                // Coalesce burst events (an install touches the directory many
                // times in quick succession) into one rescan.
                self?.scheduleRescan(delay: 0.5)
            }
            source.setCancelHandler { [descriptor] in
                close(descriptor)
            }
            source.resume()
            watchers.append(source)
        }
    }

    private func scheduleRescan(delay: TimeInterval) {
        pendingRescan?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.performRescan()
        }
        pendingRescan = task

        if delay <= 0 {
            scanQueue.async(execute: task)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, scanQueue] in
                guard let self, !task.isCancelled, self.pendingRescan === task else { return }
                scanQueue.async(execute: task)
            }
        }
    }

    private func performRescan() {
        let scanned = Self.scanApplications()
        for entry in scanned {
            switch entry {
            case .app(let app):
                _ = IconCacheService.shared.icon(forBundleIdentifier: app.bundleIdentifier)
            case .folder(let folder):
                for app in folder.apps {
                    _ = IconCacheService.shared.icon(forBundleIdentifier: app.bundleIdentifier)
                }
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.entries = scanned
        }
    }

    /// Walk each application root one level deep. A `.app` bundle becomes a
    /// top-level `.app` entry; any other directory becomes a `.folder`
    /// entry whose members are the `.app` bundles found anywhere inside it
    /// (recursively, but `.skipsPackageDescendants` prevents descent into
    /// nested .app packages). Empty subfolders are dropped, and duplicates
    /// across roots are de-duplicated by bundle id (the first occurrence
    /// wins, so /Applications takes precedence over /System/Applications
    /// for any rare overlap).
    private static func scanApplications() -> [LaunchpadEntry] {
        var seenBundleIDs = Set<String>()
        var apps: [AppTile] = []
        var folders: [AppFolderTile] = []

        for directory in applicationDirectories {
            guard let topLevel = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in topLevel {
                if url.pathExtension == "app" {
                    if let appTile = makeAppTile(from: url),
                       seenBundleIDs.insert(appTile.bundleIdentifier).inserted {
                        apps.append(appTile)
                    }
                    continue
                }

                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory else { continue }

                let nestedApps = scanSubfolderApps(in: url, seenBundleIDs: &seenBundleIDs)
                guard !nestedApps.isEmpty else { continue }

                let displayName = FileManager.default.displayName(atPath: url.path)
                folders.append(AppFolderTile(
                    identifier: "fs:\(url.standardizedFileURL.path)",
                    displayName: displayName,
                    apps: nestedApps,
                    displayMode: .grid,
                    contentViewMode: .grid
                ))
            }
        }

        var merged: [LaunchpadEntry] = []
        merged.append(contentsOf: apps.map(LaunchpadEntry.app))
        merged.append(contentsOf: folders.map(LaunchpadEntry.folder))
        merged.sort { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return merged
    }

    private static func scanSubfolderApps(in folderURL: URL, seenBundleIDs: inout Set<String>) -> [AppTile] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var apps: [AppTile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "app",
                  let app = makeAppTile(from: url),
                  seenBundleIDs.insert(app.bundleIdentifier).inserted else { continue }
            apps.append(app)
        }
        apps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return apps
    }

    private static func makeAppTile(from url: URL) -> AppTile? {
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier,
              !bundleIdentifier.isEmpty,
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        let displayName = FileManager.default.displayName(atPath: url.path)
        return AppTile(bundleIdentifier: bundleIdentifier, displayName: displayName)
    }

    deinit {
        for source in watchers {
            source.cancel()
        }
    }
}
