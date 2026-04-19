//
//  DividerTileView.swift
//  Docky
//

import SwiftUI

struct DividerTileView: View {
    private static let lineVerticalInset: CGFloat = 15

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.2))
            .frame(width: 1)
            .padding(.vertical, Self.lineVerticalInset)
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
}
