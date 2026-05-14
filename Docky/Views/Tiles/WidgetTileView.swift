//
//  WidgetTileView.swift
//  Docky
//

import SwiftUI

struct WidgetTileView: View {
    let tile: WidgetTile
    let cornerRadius: CGFloat
    let renderedSpan: TileSpan
    let isWithinStack: Bool
    var isExpanded: Bool = false
    var isExpandedPreviewOpen: Bool = false

    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif

        switch tile.kind {
        case .calendar, .calendarDate:
            CalendarWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .reminders:
            RemindersWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .batteries:
            BatteriesWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .systemStatus:
            SystemStatusWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .nowPlaying:
            NowPlayingWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .weather:
            WeatherWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        case .search:
            SearchWidgetTileView(
                tile: tile,
                cornerRadius: cornerRadius,
                renderedSpan: renderedSpan,
                isWithinStack: isWithinStack,
                isExpanded: isExpanded,
                isExpandedPreviewOpen: isExpandedPreviewOpen
            )
        }
    }
}
