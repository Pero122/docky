//
//  PermissionsWindowController.swift
//  Docky
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class PermissionsWindowPresentationModel: ObservableObject {
    @Published var companionMode = false
    @Published var screenFrame: CGRect = .zero
    @Published var companionCardFrame: CGRect?
}

private struct SystemSettingsWindowSnapshot {
    let windowNumber: CGWindowID
    let frame: CGRect
}

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PermissionsWindowController: NSWindowController {
    var onComplete: (() -> Void)?

    private let presentationModel = PermissionsWindowPresentationModel()
    private var systemSettingsFollowTimer: Timer?
    private var measuredCardSize = CGSize(width: 760, height: 640)
    private let companionGap: CGFloat = 28
    private let companionMargin: CGFloat = 24

    convenience init(steps: [Permission]) {
        let screenFrame = NSApp.keyWindow?.screen?.frame ?? NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = OnboardingWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .mainMenu + 10
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.isReleasedWhenClosed = false
        self.init(window: window)

        let view = PermissionsView(
            presentationModel: presentationModel,
            steps: steps,
            onCardSizeChange: { [weak self] size in
                self?.updateCardSize(size)
            },
            onOpenSystemSettings: { [weak self] permission in
                self?.openSystemSettingsAndFollow(permission)
            }
        ) { [weak self] in
            self?.stopFollowingSystemSettings()
            self?.close()
            self?.onComplete?()
        }
        window.contentViewController = NSHostingController(rootView: view)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        resizeWindowToActiveScreen()
    }

    override func close() {
        stopFollowingSystemSettings()
        super.close()
    }

    private func resizeWindowToActiveScreen() {
        guard let window else { return }

        let screen = window.screen ?? NSApp.keyWindow?.screen ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSScreen.screens.first?.frame ?? .zero
        guard !screenFrame.equalTo(.zero) else { return }
        window.setFrame(screenFrame, display: true)
        presentationModel.screenFrame = screenFrame
    }

    private func openSystemSettingsAndFollow(_ permission: Permission) {
        PermissionsService.shared.openSystemSettings(for: permission)
        presentationModel.companionMode = true
        window?.level = .normal
        startFollowingSystemSettings()
    }

    private func updateCardSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        measuredCardSize = size
        if presentationModel.companionMode {
            updateSystemSettingsTracking()
        }
    }

    private func startFollowingSystemSettings() {
        updateSystemSettingsTracking()

        if systemSettingsFollowTimer == nil {
            systemSettingsFollowTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateSystemSettingsTracking()
                }
            }
        }
    }

    private func stopFollowingSystemSettings() {
        systemSettingsFollowTimer?.invalidate()
        systemSettingsFollowTimer = nil
        presentationModel.companionMode = false
        presentationModel.companionCardFrame = nil
        window?.ignoresMouseEvents = false
        window?.level = .mainMenu + 10
    }

    private func updateSystemSettingsTracking() {
        guard let window else { return }
        guard let snapshot = currentSystemSettingsWindowSnapshot() else {
            stopFollowingSystemSettings()
            resizeWindowToActiveScreen()
            return
        }

        let systemSettingsFrame = snapshot.frame

        let targetScreenFrame = screenFrame(containing: systemSettingsFrame) ?? presentationModel.screenFrame
        guard !targetScreenFrame.isEmpty else { return }

        if window.frame != targetScreenFrame {
            window.setFrame(targetScreenFrame, display: true)
        }

        presentationModel.screenFrame = targetScreenFrame

        let cardFrame = companionCardFrame(for: systemSettingsFrame, in: targetScreenFrame)
        presentationModel.companionCardFrame = cardFrame
        window.ignoresMouseEvents = false
        window.order(.below, relativeTo: Int(snapshot.windowNumber))
    }

    private func currentSystemSettingsWindowSnapshot() -> SystemSettingsWindowSnapshot? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var largestSnapshot: SystemSettingsWindowSnapshot?

        for window in windows {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  ownerName == "System Settings",
                  let windowNumber = window[kCGWindowNumber as String] as? UInt32,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let windowServerFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  let frame = appKitFrame(fromWindowServerFrame: windowServerFrame),
                  !frame.isEmpty else {
                continue
            }

            let snapshot = SystemSettingsWindowSnapshot(windowNumber: windowNumber, frame: frame)
            if let currentLargestSnapshot = largestSnapshot {
                if intersectionArea(snapshot.frame) > intersectionArea(currentLargestSnapshot.frame) {
                    largestSnapshot = snapshot
                }
            } else {
                largestSnapshot = snapshot
            }
        }

        return largestSnapshot
    }

    private func screenFrame(containing frame: CGRect) -> CGRect? {
        NSScreen.screens
            .map(\.frame)
            .max { lhs, rhs in
                intersectionArea(lhs.intersection(frame)) < intersectionArea(rhs.intersection(frame))
            }
    }

    private func companionCardFrame(for systemSettingsFrame: CGRect, in screenFrame: CGRect) -> CGRect {
        let fitsOnRight = systemSettingsFrame.maxX + companionGap + measuredCardSize.width <= screenFrame.maxX - companionMargin
        let proposedX = fitsOnRight
            ? systemSettingsFrame.maxX + companionGap
            : systemSettingsFrame.minX - companionGap - measuredCardSize.width
        let proposedY = systemSettingsFrame.maxY - measuredCardSize.height

        let x = min(
            max(proposedX, screenFrame.minX + companionMargin),
            screenFrame.maxX - companionMargin - measuredCardSize.width
        )
        let y = min(
            max(proposedY, screenFrame.minY + companionMargin),
            screenFrame.maxY - companionMargin - measuredCardSize.height
        )

        return CGRect(origin: CGPoint(x: x, y: y), size: measuredCardSize)
    }

    private func intersectionArea(_ rect: CGRect) -> CGFloat {
        guard !rect.isNull, !rect.isEmpty else { return 0 }
        return rect.width * rect.height
    }

    private func appKitFrame(fromWindowServerFrame frame: CGRect) -> CGRect? {
        guard let desktopTop = NSScreen.screens.map(\.frame.maxY).max() else {
            return nil
        }

        return CGRect(
            x: frame.minX,
            y: desktopTop - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}
