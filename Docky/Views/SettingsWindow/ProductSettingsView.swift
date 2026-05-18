//
//  ProductSettingsView.swift
//  Docky
//

import AppKit
import SwiftUI

struct ProductSettingsView: View {
    @ObservedObject private var product = ProductService.shared

    private static let purchaseURL = URL(string: "https://pro.getdocky.com")!
    private static let ctaButtonHeight: CGFloat = 50
    private static let dockyAccent = Color(red: 247.0 / 255.0, green: 216.0 / 255.0, blue: 0.0 / 255.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                statusCard
                featureGrid
                ctaRow
                footnote
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient.ignoresSafeArea())
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)

            VStack(spacing: 6) {
                Text("Docky Pro")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Unlock every Docky feature on this Mac.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(statusTint)
                .frame(width: 34, height: 34)
                .background(statusTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(product.registrationStatus.title)
                        .font(.headline)
                    if product.currentTier == .pro {
                        ProBadge()
                    }
                }
                Text(product.registrationStatus.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var featureGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ProductFeature.productSettingsFeatures) { feature in
                featureCard(feature)
            }
        }
    }

    private func featureCard(_ feature: ProductFeature) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName(for: feature))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Self.dockyAccent)
                .frame(width: 32, height: 32)
                .background(Self.dockyAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                Text(feature.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }

    private var ctaRow: some View {
        VStack(spacing: 10) {
            if product.currentTier != .pro {
                Button {
                    NSWorkspace.shared.open(Self.purchaseURL)
                } label: {
                    Text("Get Docky Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Self.ctaButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)
            }

            Button {
                LicensingWindowController.present()
            } label: {
                Text(product.currentTier == .pro ? "Manage License…" : "I Already Have a License")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: Self.ctaButtonHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var footnote: some View {
        Text("Licenses can be activated on up to \(ProductService.maximumActivationCount) Macs.")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.08),
                Color.blue.opacity(0.04),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusSymbolName: String {
        switch product.registrationStatus {
        case .verified, .stored, .trialActive:
            "checkmark.seal.fill"
        case .verifying, .startingTrial:
            "hourglass"
        case .trialExpired, .verificationFailed:
            "exclamationmark.triangle.fill"
        case .unregistered:
            "lock.fill"
        }
    }

    private var statusTint: Color {
        switch product.registrationStatus {
        case .verified, .stored, .trialActive:
            .green
        case .verifying, .startingTrial:
            .orange
        case .trialExpired, .verificationFailed:
            .red
        case .unregistered:
            .secondary
        }
    }

    private func symbolName(for feature: ProductFeature) -> String {
        switch feature {
        case .launchpad:
            "square.grid.3x3.fill"
        case .windowSwitcher:
            "rectangle.stack.fill"
        case .customAppIcons:
            "paintbrush.fill"
        case .groupedAppFolders:
            "folder.fill"
        case .scriptedActions:
            "wand.and.stars"
        case .smartStack:
            "square.stack.3d.up.fill"
        case .widget:
            "rectangle.grid.2x2.fill"
        }
    }
}
