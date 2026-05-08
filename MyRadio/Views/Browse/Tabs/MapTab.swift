import SwiftUI
import MapKit
import RadioBrowserKit

private let DEFAULT_MAP_CENTER = CLLocationCoordinate2D(latitude: 20, longitude: 0)
private let DEFAULT_MAP_SPAN   = MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 360)

struct MapTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    @State private var selectedStationId: String?
    @State private var clusterMode = false
    @State private var currentSpan  = DEFAULT_MAP_SPAN
    @State private var mapPosition  = MapCameraPosition.region(
        MKCoordinateRegion(center: DEFAULT_MAP_CENTER, span: DEFAULT_MAP_SPAN)
    )

    private var geoStations: [Station] {
        state.mapStations.filter { $0.geoLat != nil && $0.geoLong != nil }
    }

    private var selectedStation: Station? {
        guard let id = selectedStationId else { return nil }
        return geoStations.first { $0.stationuuid == id }
    }

    // Grid-based O(n) clustering: cell size scales with current zoom span.
    private var clusters: [StationCluster] {
        let cell = max(currentSpan.latitudeDelta * 0.04, 0.3)
        var grid: [String: [Station]] = [:]
        for s in geoStations {
            let key = "\(Int((s.geoLat ?? 0) / cell)):\(Int((s.geoLong ?? 0) / cell))"
            grid[key, default: []].append(s)
        }
        return grid.values.map { StationCluster(stations: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarRow(subtitle: "\(geoStations.count) stations with coordinates") {
                BrowseButton(label: "Show all", icon: "map", style: .primary) {
                    resetToWorldView()
                }
                BrowseButton(
                    label: "Cluster",
                    icon: "circle.grid.3x3",
                    style: clusterMode ? .primary : .normal
                ) {
                    clusterMode.toggle()
                    selectedStationId = nil
                }
                Spacer()
                BrowseButton(label: "", icon: "arrow.clockwise", style: .ghost) {
                    Task { await reloadStations() }
                }
            }

            Map(position: $mapPosition) {
                if clusterMode {
                    ForEach(clusters) { cluster in
                        if cluster.stations.count == 1, let s = cluster.stations.first {
                            // Single station — normal pin
                            Annotation(s.name, coordinate: s.coordinate) {
                                StationPin(station: s, isSelected: selectedStationId == s.stationuuid)
                                    .onTapGesture { selectedStationId = s.stationuuid }
                            }
                        } else {
                            // Cluster pin
                            Annotation("", coordinate: cluster.coordinate) {
                                ClusterPin(count: cluster.stations.count)
                                    .onTapGesture { zoomInto(cluster) }
                            }
                        }
                    }
                } else {
                    ForEach(geoStations) { station in
                        Annotation(station.name, coordinate: station.coordinate) {
                            StationPin(
                                station: station,
                                isSelected: selectedStationId == station.stationuuid
                            )
                            .onTapGesture { selectedStationId = station.stationuuid }
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
            .onMapCameraChange { ctx in
                currentSpan = ctx.region.span
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

    // MARK: - Helpers

    private func resetToWorldView() {
        mapPosition = .region(MKCoordinateRegion(center: DEFAULT_MAP_CENTER, span: DEFAULT_MAP_SPAN))
        selectedStationId = nil
    }

    private func reloadStations() async {
        state.mapStations = []
        await state.loadTabData(for: .map)
    }

    private func zoomInto(_ cluster: StationCluster) {
        let lats  = cluster.stations.compactMap { $0.geoLat }
        let lons  = cluster.stations.compactMap { $0.geoLong }
        guard !lats.isEmpty else { return }
        let latSpan = (lats.max()! - lats.min()!) * 1.5 + 1
        let lonSpan = (lons.max()! - lons.min()!) * 1.5 + 1
        withAnimation(.easeInOut(duration: 0.4)) {
            mapPosition = .region(MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
            ))
        }
    }
}

// MARK: - Station cluster model

private struct StationCluster: Identifiable {
    let id = UUID()
    let stations: [Station]

    var coordinate: CLLocationCoordinate2D {
        let lat = stations.compactMap { $0.geoLat }.reduce(0, +) / Double(stations.count)
        let lon = stations.compactMap { $0.geoLong }.reduce(0, +) / Double(stations.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Station coordinate helper

private extension Station {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: geoLat ?? 0, longitude: geoLong ?? 0)
    }
}

// MARK: - Cluster pin

private struct ClusterPin: View {
    let count: Int
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            Circle()
                .fill(colors.accent.accent.opacity(0.85))
                .frame(width: 32, height: 32)
            Text(count < 1000 ? "\(count)" : "\(count / 1000)k")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(colors.accent.fg)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

// MARK: - Station pin

private struct StationPin: View {
    let station: Station
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(station.gradientColors.0)
            .frame(width: pinSize, height: pinSize)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.5),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.25), radius: isSelected ? 4 : 2, y: 1)
    }

    private var pinSize: CGFloat { isSelected ? 16 : 10 }
}

// MARK: - Callout overlay

private struct StationCallout: View {
    let station: Station
    let onPlay: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            StationArtwork(station: station, size: 36, cornerRadius: 6, glyphSize: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !station.countryFlag.isEmpty {
                        Text(station.countryFlag).font(.system(size: 11))
                    }
                    Text(station.countryName)
                        .font(Typography.meta).foregroundStyle(colors.fg3)
                    if let codec = station.codecDisplay {
                        Text("·").foregroundStyle(colors.fg4)
                        Text(codec).font(Typography.meta).foregroundStyle(colors.fg3)
                    }
                    if let br = station.bitrateFormatted {
                        Text("·").foregroundStyle(colors.fg4)
                        Text(br).font(Typography.meta).foregroundStyle(colors.fg3)
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
