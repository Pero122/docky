//
//  SettingsRootView.swift
//  Docky
//

import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case docky
    case appearanceIndicators
    case appearanceTileLayout
    case appearanceWindowShape
    case appearanceWindowBackground
    case behaviorPlacement
    case behaviorVisibility
    case behaviorAppTileClick
    case behaviorWidgets
    case behaviorLaunch
    case behaviorSystemDock
    case behaviorAppFolders
    case launchpad
    case windowManagement
    case appIcons
    case hiddenApps
    case permissions
    case actions
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .docky: "Docky"
        case .appearanceIndicators: "Indicators"
        case .appearanceTileLayout: "Tile Layout"
        case .appearanceWindowShape: "Window Shape"
        case .appearanceWindowBackground: "Window Background"
        case .behaviorPlacement: "Placement"
        case .behaviorVisibility: "Visibility"
        case .behaviorAppTileClick: "App Tile Click"
        case .behaviorWidgets: "Widgets"
        case .behaviorLaunch: "Launch"
        case .behaviorSystemDock: "System Dock"
        case .behaviorAppFolders: "App Folders"
        case .launchpad: "Launchpad"
        case .windowManagement: "Window Management"
        case .appIcons: "App Icons"
        case .hiddenApps: "Hidden Apps"
        case .permissions: "Permissions"
        case .actions: "Actions"
        case .updates: "Updates"
        }
    }

    var symbolName: String {
        switch self {
        case .docky: "shippingbox"
        case .appearanceIndicators: "circle.bottomhalf.filled"
        case .appearanceTileLayout: "square.grid.3x3"
        case .appearanceWindowShape: "rectangle.dashed"
        case .appearanceWindowBackground: "rectangle.fill"
        case .behaviorPlacement: "arrow.up.and.down.and.arrow.left.and.right"
        case .behaviorVisibility: "eye"
        case .behaviorAppTileClick: "cursorarrow.click"
        case .behaviorWidgets: "puzzlepiece.extension"
        case .behaviorLaunch: "power"
        case .behaviorSystemDock: "dock.rectangle"
        case .behaviorAppFolders: "folder"
        case .launchpad: "square.grid.3x3.fill"
        case .windowManagement: "rectangle.on.rectangle"
        case .appIcons: "app.badge"
        case .hiddenApps: "eye.slash"
        case .permissions: "lock.shield"
        case .actions: "list.bullet.rectangle"
        case .updates: "arrow.trianglehead.clockwise"
        }
    }

    var isPro: Bool {
        switch self {
        case .launchpad, .windowManagement, .appIcons, .actions:
            true
        default:
            false
        }
    }
}

private struct SettingsSection: Identifiable {
    let id: String
    let title: String?
    let panes: [SettingsPane]
}

private let settingsSections: [SettingsSection] = [
    SettingsSection(id: "product", title: "Product", panes: [.docky]),
    SettingsSection(id: "appearance", title: "Appearance", panes: [
        .appearanceIndicators,
        .appearanceTileLayout,
        .appearanceWindowShape,
        .appearanceWindowBackground
    ]),
    SettingsSection(id: "behavior", title: "Behavior", panes: [
        .behaviorPlacement,
        .behaviorVisibility,
        .behaviorAppTileClick,
        .behaviorWidgets,
        .behaviorLaunch,
        .behaviorSystemDock,
        .behaviorAppFolders
    ]),
    SettingsSection(id: "tools", title: nil, panes: [
        .launchpad,
        .windowManagement,
        .appIcons,
        .hiddenApps,
        .permissions,
        .actions,
        .updates
    ])
]

struct SettingsRootView: View {
    @State private var selection: SettingsPane = .docky

    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif

        NavigationSplitView {
            List(selection: $selection) {
                ForEach(settingsSections) { section in
                    if let title = section.title {
                        Section(title) {
                            paneRows(section.panes)
                        }
                    } else {
                        Section {
                            paneRows(section.panes)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .listStyle(.sidebar)
        } detail: {
            SettingsDetailView(pane: selection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func paneRows(_ panes: [SettingsPane]) -> some View {
        ForEach(panes) { pane in
            HStack(spacing: 10) {
                Label(pane.title, systemImage: pane.symbolName)
                Spacer(minLength: 8)
                if pane.isPro {
                    ProBadge()
                }
            }
            .tag(pane)
        }
    }
}

private struct SettingsDetailView: View {
    let pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            selectedView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(pane.title)
    }

    @ViewBuilder
    private var selectedView: some View {
        switch pane {
        case .docky:
            ProductSettingsView()
        case .appearanceIndicators:
            AppearanceSettingsView(subsection: .indicators)
        case .appearanceTileLayout:
            AppearanceSettingsView(subsection: .tileLayout)
        case .appearanceWindowShape:
            AppearanceSettingsView(subsection: .windowShape)
        case .appearanceWindowBackground:
            AppearanceSettingsView(subsection: .windowBackground)
        case .behaviorPlacement:
            BehaviorSettingsView(subsection: .placement)
        case .behaviorVisibility:
            BehaviorSettingsView(subsection: .visibility)
        case .behaviorAppTileClick:
            BehaviorSettingsView(subsection: .appTileClick)
        case .behaviorWidgets:
            BehaviorSettingsView(subsection: .widgets)
        case .behaviorLaunch:
            BehaviorSettingsView(subsection: .launch)
        case .behaviorSystemDock:
            BehaviorSettingsView(subsection: .systemDock)
        case .behaviorAppFolders:
            BehaviorSettingsView(subsection: .appFolders)
        case .launchpad:
            LaunchpadSettingsView()
        case .windowManagement:
            WindowManagementSettingsView()
        case .appIcons:
            AppIconsSettingsView()
        case .hiddenApps:
            HiddenAppsSettingsView()
        case .permissions:
            PermissionsSettingsView()
        case .actions:
            ActionCatalogSettingsView()
        case .updates:
            UpdatesSettingsView()
        }
    }
}
