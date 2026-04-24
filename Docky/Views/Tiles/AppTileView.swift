//
//  AppTileView.swift
//  Docky
//

import AppKit
import SwiftUI

struct AppTileView: View {
    let tile: AppTile
    let clipShape: DockClipShape
    let transparencyCompensationInset: CGFloat
    @ObservedObject private var workspace = WorkspaceService.shared

    private var isRunning: Bool {
        workspace.isRunning(bundleIdentifier: tile.bundleIdentifier)
    }

    private var isHidden: Bool {
        workspace.isHidden(bundleIdentifier: tile.bundleIdentifier)
    }

    var body: some View {
        GeometryReader { proxy in
            iconView(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func iconView(in size: CGSize) -> some View {
        if clipShape == .circle {
            ZStack {
                baseIconView(in: size)
                    .clipShape(Circle())
            }
            .glassEffect()
            .padding(transparencyCompensationInset)
        } else {
            baseIconView(in: size)
        }
    }

    private func baseIconView(in size: CGSize) -> some View {
        let inset = clipShape == .circle ? transparencyCompensationInset + 2 : 0

        return Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: clipShape == .circle ? .fill : .fit)
            .frame(width: size.width + inset / 2, height: size.height + inset / 2)
            .frame(width: size.width - inset * 2, height: size.height - inset * 2)
            .opacity(isHidden ? 0.5 : 1)
    }

    private var icon: NSImage {
        IconCacheService.shared.icon(forBundleIdentifier: tile.bundleIdentifier)
    }
}
