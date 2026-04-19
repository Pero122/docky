//
//  FolderAccessService.swift
//  Docky
//
//  Reads folder contents for preview tiles. Relies on the .userFolders
//  permission granted via Full Disk Access. Silent no-op when access isn't
//  granted.
//

import Foundation

enum FolderContentsSnapshot: Equatable {
    case loaded([URL])
    case unreadable
}

final class FolderAccessService {
    static let shared = FolderAccessService()

    private let staleAfter: TimeInterval = 15
    private var contentsCache: [URL: (date: Date, items: [URL])] = [:]

    private init() {}

    /// All visible contents of the folder, newest-modified first.
    /// Cached briefly to avoid hitting the filesystem on every view update.
    func contents(of folderURL: URL) -> [URL] {
        if case .loaded(let items) = snapshot(of: folderURL) {
            return items
        }
        return []
    }

    func snapshot(of folderURL: URL) -> FolderContentsSnapshot {
        cachedSnapshot(of: folderURL)
    }

    /// Up to `limit` URLs from the folder, newest-modified first.
    func recentContents(of folderURL: URL, limit: Int = 3) -> [URL] {
        Array(contents(of: folderURL).prefix(limit))
    }

    private func cachedSnapshot(of folderURL: URL) -> FolderContentsSnapshot {
        if let cached = contentsCache[folderURL],
           Date().timeIntervalSince(cached.date) < staleAfter {
            return .loaded(cached.items)
        }

        guard FileManager.default.isReadableFile(atPath: folderURL.path) else {
            return .unreadable
        }

        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let loaded = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ).sorted(by: { Self.modDate($0) > Self.modDate($1) }) else {
            return .unreadable
        }

        contentsCache[folderURL] = (Date(), loaded)
        return .loaded(loaded)
    }

    func invalidateCache() {
        contentsCache.removeAll()
    }

    private static func modDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
