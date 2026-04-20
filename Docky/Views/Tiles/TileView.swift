//
//  TileView.swift
//  Docky
//
//  Generic tile wrapper. Picks a concrete content view based on the tile's
//  case and applies any chrome shared across all tile types (hover, etc).
//

import AppKit
import SwiftUI

struct TileView: View {
    let tile: Tile
    @ObservedObject private var dockSettings = DockSettingsService.shared
    @ObservedObject private var preferences = DockyPreferences.shared
    @ObservedObject private var workspace = WorkspaceService.shared
    @State private var isHovering = false
    @State private var isTooltipPresented = false
    @State private var isFolderPopoverPresented = false
    @State private var isContextMenuPresented = false
    @State private var folderSnapshot: FolderContentsSnapshot = .loaded([])
    @State private var lastFolderPopoverDismissedAt: TimeInterval = 0

    private static let finderBundleIdentifier = "com.apple.finder"
    private static let folderPopoverRetapGuardInterval: TimeInterval = 0.25

    private func contextActions(modifierFlags: NSEvent.ModifierFlags) -> [ContextAction] {
        if let catalogActions = MenuCatalogService.shared.contextActions(for: tile, modifierFlags: modifierFlags) {
            switch tile.content {
            case .app, .folder, .trash:
                return catalogActions
            case .widget, .spacer, .divider:
                break
            }
        }

        switch tile.content {
        case .app(let app):
            return appContextActions(for: app, modifierFlags: modifierFlags)
        case .folder(let folder):
            return [
                .action("Open in Finder") {
                    Task {
                        _ = await AppleScriptService.shared.openFinderWindow(for: folder.url)
                    }
                },
                .action("Reveal in Finder") {
                    Task {
                        _ = await AppleScriptService.shared.revealInFinder(folder.url)
                    }
                }
            ]
        case .trash:
            return [
                .action("Open Trash") {
                    Task {
                        _ = await AppleScriptService.shared.openTrash()
                    }
                },
                .divider,
                .action("Empty Trash", isDestructive: true) {
                    Task {
                        _ = await AppleScriptService.shared.emptyTrash()
                    }
                }
            ]
        case .widget, .spacer, .divider:
            return []
        }
    }

    var body: some View {
        content
            .padding(contentPaddingEdges, contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: runningIndicatorAlignment) {
                runningIndicator
                    .padding(runningIndicatorEdge, 2)
            }
            .contentShape(Rectangle())
            .onHover(perform: updateHoverState)
            .onTapGesture(perform: handleTap)
            .onDisappear {
                isHovering = false
                isTooltipPresented = false
                isFolderPopoverPresented = false
                isContextMenuPresented = false
            }
            .onChange(of: isFolderPopoverPresented) { _, isPresented in
                guard !isPresented else { return }
                lastFolderPopoverDismissedAt = Date.timeIntervalSinceReferenceDate
            }
            .background {
                ContextActionMenuPresenter(
                    actionProvider: contextActions(modifierFlags:),
                    preferredEdge: inwardMenuEdge,
                    onPresentationChanged: updateContextMenuPresentation
                )

                if let tooltipTitle {
                    TileTooltipPopoverPresenter(
                        title: tooltipTitle,
                        isPresented: isTooltipPresented,
                        preferredEdge: inwardPopoverEdge
                    )
                    .allowsHitTesting(false)
                }
            }
            .popover(
                isPresented: $isFolderPopoverPresented,
                attachmentAnchor: folderPopoverAttachmentAnchor,
                arrowEdge: folderPopoverArrowEdge
            ) {
                if case .folder(let folder) = tile.content {
                    FolderPopoverView(
                        tile: folder,
                        initialSnapshot: folderSnapshot,
                        isPresented: $isFolderPopoverPresented
                    )
                }
            }
    }

    @ViewBuilder
    private var runningIndicator: some View {
        if case .app(let app) = tile.content,
           workspace.isRunning(bundleIdentifier: app.bundleIdentifier) {
            Circle()
                .frame(width: 4, height: 4)
                .foregroundStyle(.primary.opacity(0.9))
        }
    }

    private var contentPadding: CGFloat {
        switch tile.content {
        case .divider:
            0
        default:
            preferences.tileVerticalPadding
        }
    }

    private var contentPaddingEdges: Edge.Set {
        position.isVertical ? .horizontal : .vertical
    }

    private var position: ResolvedDockWindowPosition {
        preferences.windowPosition.resolved(systemOrientation: dockSettings.orientation)
    }

    private var runningIndicatorAlignment: Alignment {
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

    private var runningIndicatorEdge: Edge.Set {
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

    private var folderPopoverAttachmentAnchor: PopoverAttachmentAnchor {
        switch position {
        case .top:
            .point(.bottom)
        case .left:
            .point(.trailing)
        case .right:
            .point(.leading)
        case .bottom:
            .point(.top)
        }
    }

    private var folderPopoverArrowEdge: Edge {
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

    private var inwardPopoverEdge: NSRectEdge {
        switch position {
        case .top:
            .minY
        case .left:
            .maxX
        case .right:
            .minX
        case .bottom:
            .maxY
        }
    }

    private var inwardMenuEdge: NSRectEdge {
        inwardPopoverEdge
    }

    @ViewBuilder
    private var content: some View {
        switch tile.content {
        case .app(let app):
            AppTileView(tile: app)
        case .widget(let widget):
            WidgetTileView(tile: widget)
        case .folder(let folder):
            FolderTileView(tile: folder, isOpen: isFolderPopoverPresented)
        case .spacer:
            SpacerTileView()
        case .divider:
            DividerTileView()
        case .trash:
            TrashTileView()
        }
    }

    private var tooltipTitle: String? {
        switch tile.content {
        case .app(let app):
            app.displayName
        case .widget(let widget):
            widget.title
        case .folder(let folder):
            folder.displayName
        case .trash:
            "Trash"
        case .spacer, .divider:
            nil
        }
    }

    private func updateHoverState(isHovering: Bool) {
        self.isHovering = isHovering
        updateTooltipPresentation()
    }

    private func updateContextMenuPresentation(isPresented: Bool) {
        isContextMenuPresented = isPresented
        updateTooltipPresentation()
    }

    private func updateTooltipPresentation() {
        isTooltipPresented = isHovering
            && tooltipTitle != nil
            && !isFolderPopoverPresented
            && !isContextMenuPresented
    }

    private func handleTap() {
        switch tile.content {
        case .app(let app):
            isTooltipPresented = false
            WorkspaceService.shared.activateOrOpen(bundleIdentifier: app.bundleIdentifier)
        case .folder(let folder):
            isTooltipPresented = false

            if isFolderPopoverPresented {
                isFolderPopoverPresented = false
                return
            }

            let now = Date.timeIntervalSinceReferenceDate
            guard now - lastFolderPopoverDismissedAt > Self.folderPopoverRetapGuardInterval else {
                return
            }

            folderSnapshot = FolderAccessService.shared.snapshot(of: folder.url)
            isFolderPopoverPresented = true
        case .trash:
            isTooltipPresented = false
            Task {
                _ = await AppleScriptService.shared.openTrash()
            }
        case .widget, .spacer, .divider:
            return
        }
    }

    private func appContextActions(
        for app: AppTile,
        modifierFlags: NSEvent.ModifierFlags
    ) -> [ContextAction] {
        guard !app.bundleIdentifier.isEmpty else {
            return []
        }

        let workspace = WorkspaceService.shared
        let isRunning = workspace.isRunning(bundleIdentifier: app.bundleIdentifier)
        let isPinned = tile.id.hasPrefix("pinned:")
        let canTogglePinned = app.bundleIdentifier != Self.finderBundleIdentifier
        let useForceQuit = modifierFlags.contains(.option)
        var actions: [ContextAction] = [
            .action("Open") {
                workspace.activateOrOpen(bundleIdentifier: app.bundleIdentifier)
            }
        ]

        if isRunning {
            actions.append(.action("Show All Windows") {
                workspace.showAllWindows(bundleIdentifier: app.bundleIdentifier)
            })
        }

        actions.append(.divider)
        actions.append(.submenu("Options", children: appOptionsActions(for: app, isPinned: isPinned, canTogglePinned: canTogglePinned)))

        if isRunning && app.bundleIdentifier != Self.finderBundleIdentifier {
            actions.append(.divider)
            actions.append(.action("Hide") {
                workspace.hide(bundleIdentifier: app.bundleIdentifier)
            })
            actions.append(.action(
                useForceQuit ? "Force Quit" : "Quit",
                isDestructive: useForceQuit
            ) {
                workspace.quit(bundleIdentifier: app.bundleIdentifier, force: useForceQuit)
            })
        }

        return actions
    }

    private func appOptionsActions(
        for app: AppTile,
        isPinned: Bool,
        canTogglePinned: Bool
    ) -> [ContextAction] {
        var actions: [ContextAction] = []

        if canTogglePinned {
            actions.append(.action("Keep in Dock", isOn: isPinned) {
                _ = DockEditorService.shared.setPinnedApp(
                    bundleIdentifier: app.bundleIdentifier,
                    pinned: !isPinned
                )
            })
        }

        actions.append(.action("Show in Finder") {
            WorkspaceService.shared.revealApplicationInFinder(bundleIdentifier: app.bundleIdentifier)
        })

        return actions
    }

}

private struct TileTooltipView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fixedSize()
    }
}

private struct TileTooltipPopoverPresenter: NSViewRepresentable {
    let title: String
    let isPresented: Bool
    let preferredEdge: NSRectEdge

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title, preferredEdge: preferredEdge)
    }

    func makeNSView(context: Context) -> TooltipAnchorView {
        TooltipAnchorView()
    }

    func updateNSView(_ nsView: TooltipAnchorView, context: Context) {
        context.coordinator.update(title: title, preferredEdge: preferredEdge)

        if isPresented {
            context.coordinator.show(relativeTo: nsView)
        } else {
            context.coordinator.close()
        }
    }

    static func dismantleNSView(_ nsView: TooltipAnchorView, coordinator: Coordinator) {
        coordinator.close()
    }

    final class Coordinator {
        private let hostingController = NSHostingController(rootView: TileTooltipView(title: ""))
        private let popover = NSPopover()
        private var preferredEdge: NSRectEdge

        init(title: String, preferredEdge: NSRectEdge) {
            self.preferredEdge = preferredEdge
            hostingController.rootView = TileTooltipView(title: title)
            popover.contentViewController = hostingController
            popover.animates = false
            popover.behavior = .applicationDefined
            updateContentSize()
        }

        func update(title: String, preferredEdge: NSRectEdge) {
            self.preferredEdge = preferredEdge
            hostingController.rootView = TileTooltipView(title: title)
            updateContentSize()
        }

        func show(relativeTo view: NSView) {
            guard view.window != nil, !popover.isShown else { return }
            let anchorRect = anchorRect(in: view.bounds)
            popover.show(relativeTo: anchorRect, of: view, preferredEdge: preferredEdge)
        }

        func close() {
            popover.performClose(nil)
        }

        private func updateContentSize() {
            let view = hostingController.view
            view.layoutSubtreeIfNeeded()
            let size = view.fittingSize
            hostingController.preferredContentSize = size
            popover.contentSize = size
        }

        private func anchorRect(in bounds: NSRect) -> NSRect {
            switch preferredEdge {
            case .minX:
                NSRect(x: bounds.minX, y: bounds.midY - 0.5, width: 1, height: 1)
            case .maxX:
                NSRect(x: bounds.maxX - 1, y: bounds.midY - 0.5, width: 1, height: 1)
            case .minY:
                NSRect(x: bounds.midX - 0.5, y: bounds.minY, width: 1, height: 1)
            case .maxY:
                NSRect(x: bounds.midX - 0.5, y: bounds.maxY - 1, width: 1, height: 1)
            @unknown default:
                NSRect(x: bounds.midX - 0.5, y: bounds.maxY - 1, width: 1, height: 1)
            }
        }
    }
}

private final class TooltipAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
