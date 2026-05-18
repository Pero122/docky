//
//  LicensingWindowController.swift
//  Docky
//

import AppKit
import SwiftUI

@MainActor
final class LicensingWindowController: NSWindowController, NSWindowDelegate {
    private static var sharedController: LicensingWindowController?

    static func present() {
        if let controller = sharedController, controller.window != nil {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = LicensingWindowController()
        sharedController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    convenience init() {
        let hostingController = NSHostingController(rootView: LicensingView())
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 480, height: 540))
        window.minSize = NSSize(width: 440, height: 420)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.title = "Licensing"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        Self.sharedController = nil
    }
}
