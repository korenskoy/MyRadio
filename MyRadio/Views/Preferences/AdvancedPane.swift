//
//  AdvancedPane.swift
//  MyRadio
//
//  Developer / Library & cache / Diagnostics / Reset.
//  Mirrors AdvancedPane in docs/design/myradio/project/preferences.jsx,
//  but only ships the actions that are actually wired up — no stub buttons.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AdvancedPane: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    @State private var diskUsageBytes: UInt64?
    @State private var showResetConfirm = false
    @State private var importStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Advanced")
                    .font(.system(size: 22, weight: .bold))

                groupHeader("Developer")
                developerGroup

                groupHeader("Library & cache")
                libraryGroup

                groupHeader("Diagnostics")
                diagnosticsGroup

                groupHeader("Reset")
                resetGroup
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await refreshDiskUsage() }
        .alert("Reset all preferences?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                state.resetAllPreferences()
            }
        } message: {
            Text("Volume, theme, accent and the active tab will return to defaults. Favorites, history and custom stations are kept.")
        }
    }

    // MARK: Developer

    private var developerGroup: some View {
        groupBox {
            row(
                label: "DevTools window",
                hint: "Live debug log, network inspector and player state."
            ) {
                Button("Open DevTools") { openWindow(id: "devtools") }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Library & cache

    private var libraryGroup: some View {
        groupBox {
            VStack(spacing: 0) {
                row(label: "Application Support folder", monoValue: state.applicationSupportURL.path) {
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([state.applicationSupportURL])
                    }
                    .buttonStyle(.bordered)
                }
                divider
                row(label: "Artwork disk cache", monoValue: cacheUsageString) {
                    Button("Clear") {
                        Task {
                            await ArtworkCache.shared.clearAll()
                            await refreshDiskUsage()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled((diskUsageBytes ?? 0) == 0)
                }
                divider
                row(label: "Import stations from M3U/PLS", hint: importStatus) {
                    Button("Choose file…") { importFile() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Diagnostics

    private var diagnosticsGroup: some View {
        groupBox {
            VStack(spacing: 0) {
                row(
                    label: "Copy debug log to clipboard",
                    hint: "All buffered DebugLog entries — safe to share, no audio captured."
                ) {
                    Button("Copy") {
                        let text = state.debugLog.asText()
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                    }
                    .buttonStyle(.bordered)
                }
                divider
                row(label: "Clear debug log", hint: nil) {
                    Button("Clear") { state.debugLog.clear() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Reset

    private var resetGroup: some View {
        groupBox {
            row(
                label: "Reset all preferences",
                hint: "Restores defaults. Favorites, history and custom stations are kept."
            ) {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset…", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Actions

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u")  ?? .audio,
            UTType(filenameExtension: "m3u8") ?? .audio,
            UTType(filenameExtension: "pls")  ?? .audio,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importStatus = "Could not read file"
            return
        }
        importStatus = "Importing…"
        Task {
            await state.importM3U(text)
            await MainActor.run { importStatus = "Imported \(url.lastPathComponent)" }
        }
    }

    private func refreshDiskUsage() async {
        let bytes = await ArtworkCache.shared.diskUsage()
        await MainActor.run { diskUsageBytes = bytes }
    }

    private var cacheUsageString: String {
        guard let bytes = diskUsageBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: Layout helpers

    private func groupHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func groupBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func row<Trailing: View>(
        label: String,
        hint: String? = nil,
        monoValue: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                if let monoValue {
                    Text(monoValue)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}
