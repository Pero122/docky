//
//  DividerTileView.swift
//  Docky
//

import SwiftUI

struct DividerTileView: View {
    private static let lineVerticalInset: CGFloat = 15
    @ObservedObject private var dockSettings = DockSettingsService.shared
    @ObservedObject private var preferences = DockyPreferences.shared

    var body: some View {
        divider
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background {
                ContextActionMenuPresenter { _ in
                    [
                        .action("Settings...") {
                            (NSApp.delegate as? AppDelegate)?.showSettingsWindow(nil)
                        },
                        .divider,
                        .action("Quit Docky", isDestructive: true) {
                            NSApp.terminate(nil)
                        }
                    ]
                }
            }
    }

    @ViewBuilder
    private var divider: some View {
        if position.isVertical {
            Rectangle()
                .fill(.primary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, Self.lineVerticalInset)
        } else {
            Rectangle()
                .fill(.primary.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, Self.lineVerticalInset)
        }
    }

    private var position: ResolvedDockWindowPosition {
        preferences.windowPosition.resolved(systemOrientation: dockSettings.orientation)
    }
}
