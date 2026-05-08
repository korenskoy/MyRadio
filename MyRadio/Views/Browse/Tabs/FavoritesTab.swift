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
                BrowseButton(label: "", icon: "arrow.up.arrow.down", style: .ghost)
            }

            StationListSection(stations: state.favoriteStations)
        }
    }

    private func importM3U() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "m3u")!,
            .init(filenameExtension: "m3u8")!,
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
        panel.allowedContentTypes = [.init(filenameExtension: "m3u")!]
        panel.nameFieldStringValue = "stations.m3u"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? m3uText.write(to: url, atomically: true, encoding: .utf8)
    }
}
