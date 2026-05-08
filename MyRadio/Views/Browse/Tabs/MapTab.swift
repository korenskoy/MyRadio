import SwiftUI
import MapKit
import RadioBrowserKit

private let DEFAULT_MAP_CENTER = CLLocationCoordinate2D(latitude: 20, longitude: 0)
private let DEFAULT_MAP_SPAN = MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 360)

struct MapTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    @State private var selectedStationId: String?
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: DEFAULT_MAP_CENTER, span: DEFAULT_MAP_SPAN)
    )

    private var geoStations: [Station] {
        state.mapStations.filter { $0.geoLat != nil && $0.geoLong != nil }
    }

    private var selectedStation: Station? {
        guard let id = selectedStationId else { return nil }
        return geoStations.first { $0.stationuuid == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarRow(subtitle: "\(geoStations.count) stations with coordinates") {
                BrowseButton(label: "Show all", icon: "map", style: .primary) {
                    resetToWorldView()
                }
                BrowseButton(label: "Cluster", icon: "circle.grid.3x3") {}
                BrowseButton(label: "Heatmap", icon: "flame") {}
                Spacer()
                BrowseButton(label: "", icon: "arrow.clockwise", style: .ghost) {
                    Task { await reloadStations() }
                }
            }

            Map(position: $mapPosition) {
                ForEach(geoStations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationPin(
                            station: station,
                            isSelected: selectedStationId == station.stationuuid
                        )
                        .onTapGesture {
                            selectedStationId = station.stationuuid
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .mapControls {
                MapZoomStepper()
                MapCompass()
            }
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.rMd))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.rMd)
                    .strokeBorder(colors.border, lineWidth: 0.5)
            )
            .overlay(alignment: .bottom) {
                if let station = selectedStation {
                    StationCallout(station: station) {
                        state.play(station)
                    } onDismiss: {
                        selectedStationId = nil
                    }
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedStationId)
        }
    }

    private func resetToWorldView() {
        mapPosition = .region(
            MKCoordinateRegion(center: DEFAULT_MAP_CENTER, span: DEFAULT_MAP_SPAN)
        )
        selectedStationId = nil
    }

    private func reloadStations() async {
        state.mapStations = []
        await state.loadTabData(for: .map)
    }
}

// MARK: - Station coordinate helper

private extension Station {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: geoLat ?? 0,
            longitude: geoLong ?? 0
        )
    }
}

// MARK: - Pin view

private struct StationPin: View {
    let station: Station
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(station.gradientColors.0)
            .frame(width: pinSize, height: pinSize)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.5), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.25), radius: isSelected ? 4 : 2, y: 1)
    }

    private var pinSize: CGFloat {
        isSelected ? 16 : 10
    }
}

// MARK: - Callout overlay

private struct StationCallout: View {
    let station: Station
    let onPlay: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            StationArtwork(
                station: station,
                size: 36,
                cornerRadius: 6,
                glyphSize: 14
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !station.countryFlag.isEmpty {
                        Text(station.countryFlag)
                            .font(.system(size: 11))
                    }
                    Text(station.countryName)
                        .font(Typography.meta)
                        .foregroundStyle(colors.fg3)
                    if let codec = station.codecDisplay {
                        Text("·")
                            .foregroundStyle(colors.fg4)
                        Text(codec)
                            .font(Typography.meta)
                            .foregroundStyle(colors.fg3)
                    }
                    if let br = station.bitrateFormatted {
                        Text("·")
                            .foregroundStyle(colors.fg4)
                        Text(br)
                            .font(Typography.meta)
                            .foregroundStyle(colors.fg3)
                    }
                }
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(colors.accent.accent)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 24, height: 24)
                    .background(colors.bgHover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.rSm)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.rSm)
                .strokeBorder(colors.border, lineWidth: 0.5)
        )
    }
}
