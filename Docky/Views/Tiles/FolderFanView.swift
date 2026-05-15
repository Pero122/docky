//
//  FolderFanView.swift
//  Docky
//
//  Parabolic "fan" presentation of a folder's contents — the macOS
//  Dock's classic fan view, recreated as a borderless overlay window.
//  Items are positioned along a quadratic bow that sweeps upward from
//  the tile and animates in with a staggered spring per item.
//
//  Constraints (set by the caller, not enforced here):
//    - Only used when the dock is at the bottom edge.
//    - Only used for folders with ≤ FolderFanView.maximumItemCount items.
//  Both checks live in `TileView`'s overlay dispatch so that the fan
//  silently falls back to the grid popover when conditions don't hold.
//

import AppKit
import Combine
import SwiftUI

struct FolderFanView: View {
    static let maximumItemCount = 10
    /// Width of one item's bounding box. Exposed so the presenter
    /// can position the window so item 0 (the anchor at the bottom
    /// of the ellipse) lands centered above the tile.
    static let itemBoxWidth: CGFloat = 100

    let folderURL: URL
    let items: [URL]
    let onSelect: (URL) -> Void

    @State private var hasAppeared = false

    // Geometry: a quarter ellipse sweeps from item 0 at the bottom-left
    // (anchored above the tile) up and to the right to the last item
    // at the top-right of the view. `ellipseA` controls how far right
    // the fan reaches; `ellipseB` scales with item count so taller
    // fans get more vertical headroom without stretching the bow.
    private let iconSize: CGFloat = 48
    private let labelMaxWidth: CGFloat = FolderFanView.itemBoxWidth
    private let labelHeight: CGFloat = 18
    private let perItemVertical: CGFloat = 56
    private let ellipseA: CGFloat = 130

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, url in
                fanItem(url: url, index: index, total: items.count)
            }
        }
        .frame(width: viewWidth, height: viewHeight, alignment: .bottomLeading)
        .onAppear { hasAppeared = true }
    }

    @ViewBuilder
    private func fanItem(url: URL, index: Int, total: Int) -> some View {
        let t = total <= 1 ? 0 : CGFloat(index) / CGFloat(total - 1)
        // θ runs from π (item 0 at the bottom-left corner of the
        // bounding box, x=0, y=0) to π/2 (last item at the top-right,
        // x=ellipseA, y=ellipseB). cos(π)=-1 so the +1 offset places
        // item 0 exactly at the origin.
        let theta = .pi - (.pi / 2) * t
        let curveX = ellipseA * (1 + cos(theta))
        let curveY = ellipseB * sin(theta)

        Button(action: { onSelect(url) }) {
            VStack(spacing: 4) {
                Image(nsImage: IconCacheService.shared.icon(forFileURL: url))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                Text(displayName(for: url))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.black.opacity(0.55))
                    )
                    .frame(maxWidth: labelMaxWidth)
            }
            .frame(width: Self.itemBoxWidth, alignment: .center)
        }
        .buttonStyle(.plain)
        // `.position(x:y:)` is the *final* spot for this item along
        // the ellipse. `.offset(...)` is what we animate: until the
        // view appears, every item is offset back toward item 0's
        // position (the anchor at the bottom-left, right above the
        // tile), so the fan visually "shoots" each thumbnail from
        // the tile to its destination along the curve. No opacity or
        // scale — pure position animation, with a per-item stagger
        // so items leave the tile one after another.
        .position(
            x: Self.itemBoxWidth / 2 + curveX,
            y: viewHeight - (iconSize / 2 + labelHeight) - curveY
        )
        .offset(
            x: hasAppeared ? 0 : -curveX,
            y: hasAppeared ? 0 : curveY
        )
        .animation(
            .spring(response: 0.45, dampingFraction: 0.78).delay(Double(index) * 0.04),
            value: hasAppeared
        )
    }

    private var ellipseB: CGFloat {
        // The vertical span of the ellipse grows with item count so
        // each item gets roughly `perItemVertical` of clearance along
        // the arc. Floor at 0 for the single-item edge case.
        max(0, CGFloat(items.count - 1) * perItemVertical)
    }

    private var viewWidth: CGFloat {
        // ellipseA is the horizontal reach from item 0; add half an
        // item box on each side so the icons + labels don't clip.
        ellipseA + Self.itemBoxWidth
    }

    private var viewHeight: CGFloat {
        ellipseB + iconSize + labelHeight + 8
    }

    private func displayName(for url: URL) -> String {
        (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
    }
}

struct FolderFanPresenter: NSViewRepresentable {
    let folderURL: URL
    let items: [URL]
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeNSView(context: Context) -> NSView {
        // Zero-size anchor: SwiftUI ignores layout impact, but the view
        // still has a window+frame we can convert to screen coords.
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            folderURL: folderURL,
            items: items,
            isPresented: $isPresented
        )

        if isPresented {
            DispatchQueue.main.async {
                context.coordinator.present(relativeTo: nsView)
            }
        } else {
            context.coordinator.dismiss()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.dismiss()
    }

    final class Coordinator: NSObject {
        private var folderURL: URL = URL(fileURLWithPath: "/")
        private var items: [URL] = []
        var isPresented: Binding<Bool>
        private weak var window: NSWindow?
        private var globalMonitor: Any?
        private var localMonitor: Any?
        private var keyMonitor: Any?

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func update(folderURL: URL, items: [URL], isPresented: Binding<Bool>) {
            self.folderURL = folderURL
            self.items = items
            self.isPresented = isPresented
        }

        func present(relativeTo anchor: NSView) {
            guard window == nil, let anchorWindow = anchor.window else { return }

            let anchorBoundsInWindow = anchor.convert(anchor.bounds, to: nil)
            let anchorFrameInScreen = anchorWindow.convertToScreen(anchorBoundsInWindow)

            let rootView = FolderFanView(
                folderURL: folderURL,
                items: items,
                onSelect: { [weak self] url in
                    NSWorkspace.shared.open(url)
                    self?.dismiss()
                }
            )

            let hostingView = NSHostingView(rootView: rootView)
            hostingView.layout()
            let size = hostingView.fittingSize

            let newWindow = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newWindow.isReleasedWhenClosed = false
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.hasShadow = false
            newWindow.level = .mainMenu
            // The fan should never steal focus from whatever the user
            // is currently doing — same behavior as the main dock panel.
            newWindow.hidesOnDeactivate = false
            newWindow.contentView = hostingView

            // The fan is a quarter ellipse anchored at its bottom-left
            // corner: item 0 (the closest to the tile) sits in that
            // corner; the rest curve up and to the right. So place the
            // window with its bottom-left half-an-item to the left of
            // the tile center, leaving item 0 visually centered above
            // the tile while the curve sweeps off to the right.
            let originX = anchorFrameInScreen.midX - FolderFanView.itemBoxWidth / 2
            let originY = anchorFrameInScreen.maxY + 8 // gap above tile top
            newWindow.setFrameOrigin(NSPoint(x: originX, y: originY))
            newWindow.orderFrontRegardless()

            window = newWindow
            installDismissMonitors()
        }

        func dismiss() {
            guard let w = window else { return }
            removeDismissMonitors()
            w.orderOut(nil)
            window = nil

            if isPresented.wrappedValue {
                DispatchQueue.main.async { [isPresented] in
                    isPresented.wrappedValue = false
                }
            }
        }

        private func installDismissMonitors() {
            // Global: clicks anywhere outside the app.
            globalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.dismiss()
            }
            // Local: clicks inside the app but not on the fan window.
            // Returning `event` lets the click reach its real target
            // (e.g. another tile) — same feel as NSPopover.transient.
            localMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self else { return event }
                if event.window !== self.window {
                    self.dismiss()
                }
                return event
            }
            // Escape always dismisses.
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    self?.dismiss()
                    return nil
                }
                return event
            }
        }

        private func removeDismissMonitors() {
            if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
            if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
            if let k = keyMonitor { NSEvent.removeMonitor(k); keyMonitor = nil }
        }
    }
}
