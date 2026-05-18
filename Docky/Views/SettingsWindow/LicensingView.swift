//
//  LicensingView.swift
//  Docky
//

import SwiftUI

struct LicensingView: View {
    @ObservedObject private var product = ProductService.shared
    @State private var licenseKey: String = ""
    @State private var trialEmail: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCard

                section(title: "Activate License") {
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField(product.hasStoredLicenseKey ? "Replace License Key" : "License Key", text: $licenseKey)
                            .textFieldStyle(.roundedBorder)
                            .disabled(product.isVerifyingRegistration)

                        Text("License keys are verified with Gumroad and then stored locally on this Mac. Each license can be activated on up to \(ProductService.maximumActivationCount) Macs.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if product.isVerifyingRegistration {
                            ProgressView("Verifying License...")
                                .controlSize(.small)
                        }

                        HStack {
                            Spacer()
                            Button("Verify License") {
                                product.registerProduct(licenseKey: licenseKey)
                                licenseKey = ""
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || product.isVerifyingRegistration)
                        }
                    }
                }

                section(title: "Start a Trial") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Email Address", text: $trialEmail)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .disabled(product.isStartingTrial || product.currentTier == .pro)

                        Text("Trial eligibility is checked online and can only be used once per email.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if product.isStartingTrial {
                            ProgressView("Starting Trial...")
                                .controlSize(.small)
                        }

                        HStack {
                            Spacer()
                            Button("Start Trial") {
                                product.startTrial(email: trialEmail)
                            }
                            .disabled(
                                trialEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                product.currentTier == .pro ||
                                product.isStartingTrial ||
                                product.isVerifyingRegistration
                            )
                        }
                    }
                }

                if product.hasStoredLicenseKey || product.currentTier == .pro {
                    section(title: "Manage Registration") {
                        HStack {
                            Text("Sign out of this Mac and remove the stored license.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Clear Registration", role: .destructive) {
                                product.clearRegistration()
                                licenseKey = ""
                            }
                            .disabled(product.isVerifyingRegistration)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 420, idealHeight: 520)
        .onAppear {
            trialEmail = product.trialEmail
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(product.registrationStatus.title)
                    .font(.headline)
                Spacer()
                if product.currentTier == .pro {
                    ProBadge()
                } else {
                    Text(product.currentTier.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }

            Text(product.registrationStatus.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
