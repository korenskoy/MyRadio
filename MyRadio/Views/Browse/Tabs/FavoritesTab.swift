import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FavoritesTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "\(state.favoriteStations.count) stations") {
                BrowseButton(label: "Add station", icon: "plus", style: .primary) {
                    state.showAddStation = true
                }
                BrowseButton(label: "Import", icon: "square.and.arrow.up") {
                    importM3U()
                }
                BrowseButton(label: "Export M3U", icon: "square.and.arrow.down") {
                    exportM3U()
                }
                Spacer()
            }

            StationListSection(stations: state.favoriteStations)
        }
    }

    private func importM3U() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "m3u") ?? .audio,
            UTType(filenameExtension: "m3u8") ?? .audio,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        Task { await state.importM3U(text) }
    }

    private func exportM3U() {
        let m3uText = M3UParser.export(state.favoriteStations)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "m3u") ?? .audio]
        panel.nameFieldStringValue = "stations.m3u"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try m3uText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Don't let a failed write look like a successful export.
            state.debugLog.append(.error, "M3U export failed: \(error.localizedDescription)", source: "custom")
            let alert = NSAlert()
            alert.messageText = String(localized: "Couldn’t export stations")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
