import SwiftUI

struct CountriesTab: View {
    @Environment(\.appColors) private var colors

    private let countries = MockData.countries
    private var totalStations: Int {
        countries.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToolbarRow(subtitle: "\(countries.count) countries · \(totalStations.formatted()) stations total") {
                HStack(spacing: 0) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(colors.fg3)
                        .frame(width: 28)
                    Text("Filter countries...")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.fg3)
                }
                .frame(width: 240, height: 32, alignment: .leading)
                .background(colors.bgInput)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.rSm)
                        .strokeBorder(colors.borderStrong, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))

                BrowseButton(label: "By name", icon: "arrow.up.arrow.down", style: .ghost)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 8)
            ], spacing: 8) {
                ForEach(countries, id: \.code) { country in
                    CountryCard(country: country)
                }
            }
        }
    }
}

private struct CountryCard: View {
    let country: (code: String, name: String, count: Int, flag: String)
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(country.flag)
                .font(.system(size: 22))

            Text(country.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(colors.fg)
                .lineLimit(1)

            Spacer()

            Text(country.count.formatted())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(colors.fg3)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.rSm)
                .fill(hovered ? colors.accent.soft : colors.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.rSm)
                .strokeBorder(hovered ? colors.accent.accent : colors.border, lineWidth: 0.5)
        )
        .onHover { hovered = $0 }
        .contentShape(Rectangle())
    }
}
