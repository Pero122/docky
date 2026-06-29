//
//  UpdatesSettingsView.swift
//  Docky
//

import SwiftUI

struct UpdatesSettingsView: View {
    var body: some View {
        Form {
            Section("Updates") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Software updates are disabled in this fork", systemImage: "lock.fill")
                        .font(.headline)

                    Text("""
                    This is a fork of Docky. Its update feed points at the upstream \
                    getdocky.com build, so installing an update would replace this \
                    fork with the official app and wipe its changes. Updates are \
                    turned off at the source and cannot be re-enabled.

                    To update, rebuild from source or install a newer build from the \
                    fork's GitHub Releases page.
                    """)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}
