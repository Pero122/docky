//
//  MainWindow.swift
//  Docky
//
//  Created by Jose Quintero on 17/04/26.
//

import AppKit
import Combine

final class MainWindowContainerView: NSView {
    static let contentPadding: CGFloat = 2

    private let contentView = MainWindowView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentPadding),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.contentPadding),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentPadding),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.contentPadding),
        ])
    }
}

final class MainWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override var level: NSWindow.Level { get { .mainMenu } set {} }

    private let backgroundBlurRadius = 10
    private let dockSettings = DockSettingsService.shared
    private let preferences = DockyPreferences.shared
    private let tileStore = TileStore.shared
    private let minimumWidth: CGFloat = 120
    private var cancellables: Set<AnyCancellable> = []

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        backgroundColor = .clear
        isOpaque = false
        isMovableByWindowBackground = true
        observeFrameInputs()
    }

    override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        applyBackgroundBlur()
    }

    private func applyBackgroundBlur() {
        guard windowNumber > 0 else { return }
        _ = CGSSetWindowBackgroundBlurRadius(
            CGSMainConnectionID(),
            windowNumber,
            backgroundBlurRadius
        )
    }

    private func observeFrameInputs() {
        let signals: [AnyPublisher<Void, Never>] = [
            dockSettings.$orientation.map { _ in () }.eraseToAnyPublisher(),
            dockSettings.$tileSize.map { _ in () }.eraseToAnyPublisher(),
            dockSettings.$largeSize.map { _ in () }.eraseToAnyPublisher(),
            dockSettings.$magnification.map { _ in () }.eraseToAnyPublisher(),
            preferences.$tileVerticalPadding.map { _ in () }.eraseToAnyPublisher(),
            preferences.$tileSpacing.map { _ in () }.eraseToAnyPublisher(),
            preferences.$windowPosition.map { _ in () }.eraseToAnyPublisher(),
            tileStore.$tiles.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(signals)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyFrame() }
            .store(in: &cancellables)
    }

    private func applyFrame() {
        let screenBounds = screen?.frame ?? NSScreen.main?.frame ?? .zero
        let iconHeight = dockSettings.magnification ? dockSettings.largeSize : dockSettings.tileSize
        let contentPadding = MainWindowContainerView.contentPadding
        let tileHeight = iconHeight + preferences.tileVerticalPadding * 2
        let position = preferences.windowPosition.resolved(systemOrientation: dockSettings.orientation)

        let contentSize = TileContainerView.contentSize(
            tiles: tileStore.tiles,
            tileSize: dockSettings.tileSize,
            tileHeight: tileHeight,
            tileSpacing: preferences.tileSpacing,
            position: position
        )
        let width = (position.isVertical ? contentSize.width : max(minimumWidth, contentSize.width)) + contentPadding * 2
        let height = contentSize.height + contentPadding * 2
        let origin = frameOrigin(in: screenBounds, size: CGSize(width: width, height: height), position: position)

        setFrame(
            CGRect(
                x: origin.x,
                y: origin.y,
                width: width,
                height: height
            ),
            display: true,
            animate: false
        )
    }

    private func frameOrigin(
        in screenBounds: CGRect,
        size: CGSize,
        position: ResolvedDockWindowPosition
    ) -> CGPoint {
        switch position {
        case .top:
            CGPoint(
                x: screenBounds.minX + (screenBounds.width - size.width) / 2,
                y: screenBounds.maxY - size.height
            )
        case .left:
            CGPoint(
                x: screenBounds.minX,
                y: screenBounds.minY + (screenBounds.height - size.height) / 2
            )
        case .right:
            CGPoint(
                x: screenBounds.maxX - size.width,
                y: screenBounds.minY + (screenBounds.height - size.height) / 2
            )
        case .bottom:
            CGPoint(
                x: screenBounds.minX + (screenBounds.width - size.width) / 2,
                y: screenBounds.minY
            )
        }
    }
}
