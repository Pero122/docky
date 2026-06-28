//
//  DockSectionModel.swift
//  Docky
//
//  Foundation for the modular dock-groups architecture (Goal 1). Today the dock
//  hardcodes three groups — pinned / running / trailing — wired through the tile
//  assembly, the drag system and persistence. This replaces that with a generic,
//  data-driven model: the dock is an ORDERED LIST of `DockSection`s, each holding
//  an array of behaviour `SectionTag`s that decide *defaults only*. A new item
//  lands in the first section carrying the matching tag, but from then on the user
//  can drag any tile into any section at any slot — the section's `tileIDs` order
//  IS the persisted truth. Add a 4th/5th separator later = append another section.
//
//  Kept free of any app/AppKit types so it can be unit-tested standalone (see
//  Tests/standalone/DockSectionModelTests.swift) and so a per-screen
//  `DockScreenContext` can own a value copy without singletons (multi-screen
//  pillar — see the handoff).
//

/// A behaviour tag on a section. Tags decide only where a *new* item lands by
/// default; they never pin a tile to a section (the user can always drag it out).
enum SectionTag: String, Equatable {
    /// Newly-pinned apps land here. (Today: the left/pinned group.)
    case defaultPin
    /// Apps that start while not pinned land here. (Today: the middle/running group.)
    case absorbsRunningUnpinned
    /// Trash, folders and other trailing items land here. (Today: the right group.)
    case trailing
}

/// One dock group. `tileIDs` is the ordered, user-editable contents;
/// `leadingDividerID`, when set, is the divider tile inserted before this section
/// in the assembled list (only when both this and a preceding section are present).
struct DockSection: Equatable {
    let id: String
    var tags: [SectionTag]
    var leadingDividerID: String?
    var tileIDs: [String]

    init(id: String, tags: [SectionTag] = [], leadingDividerID: String? = nil, tileIDs: [String] = []) {
        self.id = id
        self.tags = tags
        self.leadingDividerID = leadingDividerID
        self.tileIDs = tileIDs
    }

    func hasTag(_ tag: SectionTag) -> Bool { tags.contains(tag) }
}

/// The kind of a freshly-appearing item, mapped to the tag that attracts it.
enum NewItemKind {
    case pinnedApp
    case runningUnpinned
    case trailingItem

    var preferredTag: SectionTag {
        switch self {
        case .pinnedApp: return .defaultPin
        case .runningUnpinned: return .absorbsRunningUnpinned
        case .trailingItem: return .trailing
        }
    }
}

/// Pure operations over an ordered `[DockSection]`. Every function is total and
/// side-effect-free, returning a new arrangement, so the live store can diff and
/// persist the result and the same logic can be exercised by standalone tests.
enum DockSectionArrangement {
    /// The id of the section a new item of `kind` should default into: the first
    /// section carrying the matching tag, or `nil` if no section accepts it.
    static func defaultSectionID(for kind: NewItemKind, in sections: [DockSection]) -> String? {
        sections.first(where: { $0.hasTag(kind.preferredTag) })?.id
    }

    /// Appends `tileID` to the section that should hold a new item of `kind`,
    /// unless it is already present somewhere. Returns `sections` unchanged when
    /// there's no accepting section or the tile already exists (so callers can
    /// skip a redundant write).
    static func placeNewTile(_ tileID: String, kind: NewItemKind, in sections: [DockSection]) -> [DockSection] {
        guard sections.allSatisfy({ !$0.tileIDs.contains(tileID) }),
              let sid = defaultSectionID(for: kind, in: sections),
              let index = sections.firstIndex(where: { $0.id == sid })
        else { return sections }
        var result = sections
        result[index].tileIDs.append(tileID)
        return result
    }

    /// Moves `tileID` to `sectionID` at `index` (clamped to the target's bounds),
    /// removing it from whatever section currently holds it. This is the
    /// "drag anything anywhere" primitive. Returns `sections` unchanged when the
    /// target section doesn't exist.
    static func move(tileID: String, toSectionID sectionID: String, atIndex index: Int, in sections: [DockSection]) -> [DockSection] {
        guard let targetIndex = sections.firstIndex(where: { $0.id == sectionID }) else { return sections }
        var result = sections
        for i in result.indices {
            result[i].tileIDs.removeAll { $0 == tileID }
        }
        let clamped = max(0, min(index, result[targetIndex].tileIDs.count))
        result[targetIndex].tileIDs.insert(tileID, at: clamped)
        return result
    }

    /// Reconciles a user's saved arrangement against the freshly-computed default
    /// sections (membership derived from app state each rebuild). This is the
    /// source-of-truth bridge for "drag anything anywhere": a tile placed by the
    /// user in `saved[sectionID]` renders in THAT section (a cross-section move
    /// that sticks), regardless of which group it defaults to; everything else
    /// stays in its default section. Within a section, user-placed tiles come
    /// first in saved order, then the remaining default tiles in default order.
    /// Saved entries for tiles that no longer exist (quit apps, removed pins) are
    /// ignored, and an empty `saved` returns the defaults unchanged (parity).
    static func reconcile(defaults: [DockSection], saved: [String: [String]]) -> [DockSection] {
        let existing = Set(defaults.flatMap(\.tileIDs))

        // A tile's user placement: the first default section whose saved list
        // names it (iterating in section order keeps this deterministic). Only
        // existing tiles and real sections participate, so stale/invalid saved
        // entries are silently dropped.
        var placement: [String: String] = [:]
        for section in defaults {
            guard let savedList = saved[section.id] else { continue }
            for tileID in savedList where existing.contains(tileID) && placement[tileID] == nil {
                placement[tileID] = section.id
            }
        }

        var defaultSection: [String: String] = [:]
        for section in defaults {
            for tileID in section.tileIDs { defaultSection[tileID] = section.id }
        }
        func targetSection(of tileID: String) -> String? { placement[tileID] ?? defaultSection[tileID] }

        return defaults.map { section in
            var ordered: [String] = []
            var seen = Set<String>()
            // 1. User-placed tiles for this section, in saved order.
            for tileID in saved[section.id] ?? []
            where existing.contains(tileID) && targetSection(of: tileID) == section.id && seen.insert(tileID).inserted {
                ordered.append(tileID)
            }
            // 2. Tiles that default here and aren't placed elsewhere, in default order.
            for tileID in section.tileIDs
            where targetSection(of: tileID) == section.id && seen.insert(tileID).inserted {
                ordered.append(tileID)
            }
            var result = section
            result.tileIDs = ordered
            return result
        }
    }

    /// Flattens the sections into the final ordered tile-id list, inserting a
    /// section's `leadingDividerID` before it only when it is non-empty AND some
    /// earlier section already contributed tiles — so empty groups (and the
    /// leading edge) never emit a stray divider.
    static func assemble(_ sections: [DockSection]) -> [String] {
        var result: [String] = []
        for section in sections where !section.tileIDs.isEmpty {
            if !result.isEmpty, let divider = section.leadingDividerID {
                result.append(divider)
            }
            result.append(contentsOf: section.tileIDs)
        }
        return result
    }
}
