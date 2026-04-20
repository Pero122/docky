//
//  TileContainerView.swift
//  Docky
//

import SwiftUI

struct TileContainerView: View {
    static let edgePadding: CGFloat = 8
    static let dividerWidth: CGFloat = 40
    private let tileMutationAnimation: Animation = .easeInOut(duration: 0.18)

    @ObservedObject private var store = TileStore.shared
    @ObservedObject private var dockSettings = DockSettingsService.shared
    @ObservedObject private var preferences = DockyPreferences.shared

    var body: some View {
        Group {
            if position.isVertical {
                VStack(spacing: preferences.tileSpacing) {
                    tileViews
                }
                .padding(.vertical, Self.edgePadding)
            } else {
                HStack(spacing: preferences.tileSpacing) {
                    tileViews
                }
                .padding(.horizontal, Self.edgePadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(tileMutationAnimation, value: store.tiles)
    }

    @ViewBuilder
    private var tileViews: some View {
        ForEach(store.tiles) { tile in
            let size = Self.size(for: tile, tileSize: dockSettings.tileSize, tileHeight: tileHeight, position: position)
            TileView(tile: tile)
                .frame(width: size.width, height: size.height)
                .transition(tileTransition)
        }
    }

    private var tileTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9, anchor: tileScaleAnchor).combined(with: .opacity),
            removal: .scale(scale: 0.9, anchor: tileScaleAnchor).combined(with: .opacity)
        )
    }

    private var tileScaleAnchor: UnitPoint {
        switch position {
        case .top:
            .top
        case .left:
            .leading
        case .right:
            .trailing
        case .bottom:
            .bottom
        }
    }

    private var tileHeight: CGFloat {
        let iconHeight = dockSettings.magnification ? dockSettings.largeSize : dockSettings.tileSize
        return iconHeight + preferences.tileVerticalPadding * 2
    }

    private var position: ResolvedDockWindowPosition {
        preferences.windowPosition.resolved(systemOrientation: dockSettings.orientation)
    }

    static func size(
        for tile: Tile,
        tileSize: CGFloat,
        tileHeight: CGFloat,
        position: ResolvedDockWindowPosition
    ) -> CGSize {
        switch (position.isVertical, tile.content) {
        case (false, .divider):
            CGSize(width: dividerWidth, height: tileHeight)
        case (false, _):
            CGSize(width: tileSize, height: tileHeight)
        case (true, .divider):
            CGSize(width: tileHeight, height: dividerWidth)
        case (true, _):
            CGSize(width: tileHeight, height: tileSize)
        }
    }

    /// Total content size for the given tile list, including inter-tile spacing
    /// and outer stack padding. Used by MainWindow to size itself to fit.
    static func contentSize(
        tiles: [Tile],
        tileSize: CGFloat,
        tileHeight: CGFloat,
        tileSpacing: CGFloat,
        position: ResolvedDockWindowPosition
    ) -> CGSize {
        let sizes = tiles.map { size(for: $0, tileSize: tileSize, tileHeight: tileHeight, position: position) }
        let spacings = max(0, CGFloat(tiles.count) - 1) * tileSpacing

        if position.isVertical {
            let height = sizes.reduce(CGFloat(0)) { $0 + $1.height } + spacings + edgePadding * 2
            let width = sizes.map(\.width).max() ?? tileSize
            return CGSize(width: width, height: height)
        }

        let width = sizes.reduce(CGFloat(0)) { $0 + $1.width } + spacings + edgePadding * 2
        let height = sizes.map(\.height).max() ?? tileHeight
        return CGSize(width: width, height: height)
    }
}
