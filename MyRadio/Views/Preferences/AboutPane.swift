//
//  AboutPane.swift
//  MyRadio
//
//  About + Updates + Resources, mirrors AboutPane in
//  docs/design/myradio/project/preferences.jsx.
//

import SwiftUI
import AppKit

struct AboutPane: View {
    @EnvironmentObject private var updateChecker: UpdateChecker
    @Environment(\.openURL) private var openURL

    private static let repoURL = URL(string: "https://github.com/korenskoy/MyRadio")!
    private static let releasesURL = URL(string: "https://github.com/korenskoy/MyRadio/releases")!
    private static let licenseURL = URL(string: "https://github.com/korenskoy/MyRadio/blob/main/LICENSE")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                updateCard
                groupHeader("Updates")
                autoCheckRow
                groupHeader("Resources")
                resourcesGroup
                credits
                footnote
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Hero

    private var hero: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text("MyRadio")
                    .font(.system(size: 26, weight: .bold))
                Text("Native radio client for macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    chip("Version \(AppVersion.marketing)")
                    chip("Build \(AppVersion.build)")
                    chip("macOS 26.4+")
                }
                .padding(.top, 2)
            }
            Spacer()
        }
    }

    private func chip(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }

    // MARK: Update card

    private var updateCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(statusSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            primaryActionButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        if updateChecker.availableUpdate != nil { return .orange }
        if updateChecker.lastCheckedAt != nil   { return .green }
        return .secondary
    }

    private var statusTitle: String {
        if let update = updateChecker.availableUpdate {
            return String(localized: "Update available — version \(update.version)")
        }
        if updateChecker.lastCheckedAt != nil { return String(localized: "You're up to date") }
        return String(localized: "Not checked yet")
    }

    private var statusSubtitle: String {
        if updateChecker.isChecking { return String(localized: "Checking GitHub for new releases…") }
        let last = UpdateStatusFormatter.lastChecked(at: updateChecker.lastCheckedAt)
        if let next = UpdateStatusFormatter.nextCheck(
            after: updateChecker.lastCheckedAt,
            interval: updateChecker.checkInterval
        ), updateChecker.autoCheckOnLaunch {
            return "\(last) · \(next)"
        }
        return last
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if let update = updateChecker.availableUpdate {
            Button {
                openURL(update.url)
            } label: {
                Label("Open release", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                Task { await updateChecker.checkNow() }
            } label: {
                if updateChecker.isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Check now", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(updateChecker.isChecking)
        }
    }

    // MARK: Auto-check toggle

    private var autoCheckRow: some View {
        groupBox {
            HStack {
                Text("Auto-check on launch")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { updateChecker.autoCheckOnLaunch },
                    set: { updateChecker.autoCheckOnLaunch = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: Resources

    private var resourcesGroup: some View {
        groupBox {
            VStack(spacing: 0) {
                resourceRow(icon: "globe", title: "Website", url: Self.repoURL)
                divider
                resourceRow(icon: "doc.text", title: "Release notes", url: Self.releasesURL)
                divider
                resourceRow(icon: "arrow.up.right.square", title: "GitHub", url: Self.repoURL)
                divider
                resourceRow(icon: "doc.plaintext", title: "License (MIT)", url: Self.licenseURL)
            }
        }
    }

    private func resourceRow(icon: String, title: LocalizedStringKey, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var credits: some View {
        HStack(spacing: 6) {
            Text("♥").foregroundStyle(.pink)
            Text("Powered by the **radio-browser.info** community API")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    private var footnote: some View {
        Text("© 2026 MyRadio · Not affiliated with any broadcaster")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }

    // MARK: Helpers

    private func groupHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(.uppercase)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func groupBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}
