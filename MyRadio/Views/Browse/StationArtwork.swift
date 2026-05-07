import SwiftUI
import RadioBrowserKit

struct StationArtwork: View {
    let station: Station
    let size: CGFloat
    var cornerRadius: CGFloat = 6
    var glyphSize: CGFloat = 16

    @State private var image: NSImage?

    var body: some View {
        let (c1, c2) = station.gradientColors

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [c1, c2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(station.glyph)
                    .font(.system(size: glyphSize, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: station.stationuuid) {
            image = await ArtworkCache.shared.image(
                for: station.stationuuid,
                faviconURL: station.favicon
            )
        }
    }
}
