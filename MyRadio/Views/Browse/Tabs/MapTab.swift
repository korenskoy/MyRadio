import SwiftUI
import MapKit
import RadioBrowserKit

private let DEFAULT_REGION = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
    span:   MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 360)
)

// MARK: - Tab shell

struct MapTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    @State private var selectedStation: Station?
    @State private var clusterMode = true
    @State private var requestedRegion: MKCoordinateRegion? = nil

    private var geoStations: [Station] {
        state.mapStations.filter { $0.geoLat != nil && $0.geoLong != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarRow {
                BrowseButton(label: "Show all", icon: "map", style: .primary) {
                    requestedRegion = DEFAULT_REGION
                    selectedStation = nil
                }
                BrowseButton(
                    label: "Cluster",
                    icon: "circle.grid.3x3",
                    style: clusterMode ? .primary : .normal
                ) {
                    clusterMode.toggle()
                    selectedStation = nil
                }
                Spacer()
                Text("\(geoStations.count) stations with coordinates")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
                BrowseButton(label: "", icon: "arrow.clockwise", style: .ghost) {
                    Task { await state.reloadMapStations() }
                }
            }

            MapKitView(
                stations: geoStations,
                clusterMode: clusterMode,
                selectedStation: $selectedStation,
                requestedRegion: $requestedRegion
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        selectedStation = nil
                    }
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedStation?.stationuuid)
        }
    }

}

// MARK: - NSViewRepresentable

private struct MapKitView: NSViewRepresentable {
    let stations: [Station]
    let clusterMode: Bool
    @Binding var selectedStation: Station?
    @Binding var requestedRegion: MKCoordinateRegion?

    func makeNSView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.register(StationAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: StationAnnotationView.reuseID)
        mv.register(ClusterAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mv.setRegion(DEFAULT_REGION, animated: false)
        return mv
    }

    func updateNSView(_ mv: MKMapView, context: Context) {
        let c = context.coordinator
        let clusterChanged = c.clusterMode != clusterMode
        c.parent = self
        c.clusterMode = clusterMode

        // Reload annotations when stations or cluster mode changes
        let currentIds = Set(mv.annotations.compactMap { ($0 as? StationAnnotation)?.station.stationuuid })
        let newIds     = Set(stations.map { $0.stationuuid })
        if currentIds != newIds || clusterChanged {
            mv.removeAnnotations(mv.annotations)
            mv.addAnnotations(stations.map { StationAnnotation($0) })
        }

        // Honour requested region (Show all / external zoom)
        if let region = requestedRegion {
            mv.setRegion(region, animated: true)
            DispatchQueue.main.async { self.requestedRegion = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitView
        var clusterMode: Bool

        init(_ parent: MapKitView) {
            self.parent = parent
            self.clusterMode = parent.clusterMode
        }

        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKClusterAnnotation {
                return mv.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: annotation)
            }
            guard annotation is StationAnnotation else { return nil }
            let view = mv.dequeueReusableAnnotationView(
                withIdentifier: StationAnnotationView.reuseID,
                for: annotation) as! StationAnnotationView
            view.clusteringIdentifier = clusterMode ? "station" : nil
            return view
        }

        func mapView(_ mv: MKMapView, didSelect view: MKAnnotationView) {
            if let sa = view.annotation as? StationAnnotation {
                DispatchQueue.main.async { self.parent.selectedStation = sa.station }
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                mv.deselectAnnotation(view.annotation!, animated: false)
                mv.showAnnotations(cluster.memberAnnotations, animated: true)
            }
        }

        func mapView(_ mv: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is StationAnnotation {
                DispatchQueue.main.async { self.parent.selectedStation = nil }
            }
        }
    }
}

// MARK: - Annotation model

private final class StationAnnotation: NSObject, MKAnnotation {
    let station: Station
    var coordinate: CLLocationCoordinate2D
    var title: String? { station.name }

    init(_ station: Station) {
        self.station = station
        coordinate = CLLocationCoordinate2D(latitude: station.geoLat ?? 0,
                                            longitude: station.geoLong ?? 0)
    }
}

// MARK: - Station pin view

private final class StationAnnotationView: MKAnnotationView {
    static let reuseID = "station"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 11, height: 11)
        canShowCallout = false
        wantsLayer = true
        layer?.cornerRadius = 5.5
        layer?.backgroundColor = NSColor(calibratedRed: 0.30, green: 0.76, blue: 0.36, alpha: 1).cgColor
        layer?.borderColor   = NSColor.white.cgColor
        layer?.borderWidth   = 1
        layer?.shadowColor   = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius  = 2
        layer?.shadowOffset  = CGSize(width: 0, height: -1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let size: CGFloat = selected ? 16 : 11
        frame = CGRect(x: -size/2, y: -size/2, width: size, height: size)
        layer?.cornerRadius = size / 2
        layer?.borderWidth  = selected ? 2 : 1
    }
}

// MARK: - Cluster pin view

private final class ClusterAnnotationView: MKAnnotationView {
    private let label: NSTextField = {
        let tf = NSTextField()
        tf.isBezeled = false; tf.isEditable = false; tf.isSelectable = false
        tf.drawsBackground = false; tf.alignment = .center
        tf.textColor = .white
        tf.font = .systemFont(ofSize: 10, weight: .bold)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        canShowCallout = false
        wantsLayer = true
        layer?.cornerRadius  = 17
        layer?.backgroundColor = NSColor(calibratedRed: 0.30, green: 0.76, blue: 0.36, alpha: 0.88).cgColor
        layer?.borderColor   = NSColor.white.withAlphaComponent(0.4).cgColor
        layer?.borderWidth   = 1
        layer?.shadowColor   = NSColor.black.cgColor
        layer?.shadowOpacity = 0.25
        layer?.shadowRadius  = 3
        layer?.shadowOffset  = CGSize(width: 0, height: -1)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var annotation: MKAnnotation? {
        didSet {
            guard let c = annotation as? MKClusterAnnotation else { return }
            let n = c.memberAnnotations.count
            label.stringValue = n < 1000 ? "\(n)" : "\(n / 1000)k"
        }
    }
}

// MARK: - Station coordinate helper

private extension Station {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: geoLat ?? 0, longitude: geoLong ?? 0)
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
            StationArtwork(station: station, size: 36, cornerRadius: 6, glyphSize: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.fg).lineLimit(1)
                HStack(spacing: 6) {
                    if !station.countryFlag.isEmpty {
                        Text(station.countryFlag).font(.system(size: 11))
                    }
                    Text(station.countryName).font(Typography.meta).foregroundStyle(colors.fg3)
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
            }.buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 24, height: 24)
                    .background(colors.bgHover)
                    .clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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
