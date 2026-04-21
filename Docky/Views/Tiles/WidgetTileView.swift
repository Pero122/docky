//
//  WidgetTileView.swift
//  Docky
//

import SwiftUI

struct WidgetTileView: View {
    let tile: WidgetTile
    let cornerRadius: CGFloat

    var body: some View {
        switch tile.kind {
        case .nowPlaying:
            NowPlayingWidgetTileView(tile: tile, cornerRadius: cornerRadius)
        }
    }
}
