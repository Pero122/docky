//
//  WidgetHoverGrowService.swift
//  Docky
//

import Combine
import Foundation

final class WidgetHoverGrowService: ObservableObject {
    static let shared = WidgetHoverGrowService()

    @Published private(set) var activeExtent: WidgetExpansionExtent?

    var isActive: Bool { activeExtent != nil }

    private var hoveredExtents: [String: WidgetExpansionExtent] = [:]

    private init() {}

    func isHovered(identifier: String) -> Bool {
        hoveredExtents[identifier] != nil
    }

    func setHovered(_ hovered: Bool, identifier: String, extent: WidgetExpansionExtent = .standard) {
        if hovered {
            hoveredExtents[identifier] = extent
        } else {
            hoveredExtents.removeValue(forKey: identifier)
        }

        let next = aggregatedExtent()
        if next != activeExtent {
            activeExtent = next
        }
    }

    private func aggregatedExtent() -> WidgetExpansionExtent? {
        guard !hoveredExtents.isEmpty else { return nil }
        let maxWidth = hoveredExtents.values.map(\.widthTiles).max() ?? WidgetExpansionExtent.standard.widthTiles
        let maxHeight = hoveredExtents.values.map(\.heightTiles).max() ?? WidgetExpansionExtent.standard.heightTiles
        return WidgetExpansionExtent(widthTiles: maxWidth, heightTiles: maxHeight)
    }
}
