import SwiftUI
import RadioBrowserKit

struct CountriesTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var sortByName = false
    @State private var selectedCountry: NamedCount?
    @State private var isLoadingStations = false

    private var totalStations: Int {
        state.apiCountries.reduce(0) { $0 + $1.stationcount }
    }

    private var sortedCountries: [NamedCount] {
        if sortByName {
            state.apiCountries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            state.apiCountries
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let country = selectedCountry {
                countryDetail(country)
            } else {
                countriesList
            }
        }
    }

    // MARK: - Countries grid

    @ViewBuilder
    private var countriesList: some View {
        ToolbarRow(subtitle: "\(state.apiCountries.count) countries · \(totalStations.formatted()) stations total") {
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

            BrowseButton(
                label: sortByName ? "By count" : "By name",
                icon: "arrow.up.arrow.down",
                style: .ghost,
                action: { sortByName.toggle() }
            )
        }

        if state.apiCountries.isEmpty {
            ContentUnavailableView("Loading countries…", systemImage: "globe")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 8)
            ], spacing: 8) {
                ForEach(sortedCountries) { country in
                    CountryCard(country: country) {
                        selectedCountry = country
                        isLoadingStations = true
                        Task {
                            await state.loadStationsForCountry(country.name)
                            isLoadingStations = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Country detail

    @ViewBuilder
    private func countryDetail(_ country: NamedCount) -> some View {
        HStack(spacing: 8) {
            Button {
                selectedCountry = nil
                state.selectedCountryCode = nil
                state.countryStations = []
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(colors.accent.accent)
            }
            .buttonStyle(.plain)

            Text(CountryFlag.emoji(for: country.name))
                .font(.system(size: 16))

            Text(CountryFlag.displayName(for: country.name))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.fg)

            Spacer()

            Text("\(state.countryStations.count) stations")
                .font(Typography.meta)
                .foregroundStyle(colors.fg3)
        }
        .padding(.bottom, 14)

        if isLoadingStations {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            StationListSection(
                stations: state.countryStations
            )
        }
    }
}

// MARK: - Country flag + display name helper

enum CountryFlag {
    /// Emoji flag for a raw API country name.
    static func emoji(for name: String) -> String {
        isoCode(for: name).map(flagEmoji) ?? "🌐"
    }

    /// Clean display name from the locale (e.g. "Russia" instead of "The Russian Federation").
    static func displayName(for name: String) -> String {
        guard let code = isoCode(for: name) else { return name }
        return Locale(identifier: "en_US").localizedString(forRegionCode: code) ?? name
    }

    // MARK: Private

    private static func isoCode(for name: String) -> String? {
        let lower = name.lowercased()
        if let c = lookup[lower]                    { return c }  // exact match
        if let c = aliases[lower]                   { return c }  // known alias
        let stripped = lower.hasPrefix("the ") ? String(lower.dropFirst(4)) : lower
        if let c = lookup[stripped]                 { return c }  // strip "The "
        if let c = aliases[stripped]                { return c }
        return nil
    }

    private static func flagEmoji(code: String) -> String {
        let base: UInt32 = 127397
        return String(code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { Character($0) })
    }

    private static let lookup: [String: String] = {
        var map: [String: String] = [:]
        for id in Locale.Region.isoRegions {
            if let name = Locale(identifier: "en_US").localizedString(forRegionCode: id.identifier) {
                map[name.lowercased()] = id.identifier
            }
        }
        return map
    }()

    // Known API names that don't match locale strings even after stripping "The".
    private static let aliases: [String: String] = [
        "russian federation":              "RU",
        "united states of america":        "US",
        "korea, republic of":              "KR",
        "republic of korea":               "KR",
        "korea, democratic people's republic of": "KP",
        "iran, islamic republic of":       "IR",
        "syrian arab republic":            "SY",
        "viet nam":                        "VN",
        "czech republic":                  "CZ",
        "republic of moldova":             "MD",
        "tanzania, united republic of":    "TZ",
        "taiwan, province of china":       "TW",
        "bolivia, plurinational state of": "BO",
        "venezuela, bolivarian republic of": "VE",
        "micronesia, federated states of": "FM",
        "congo, the democratic republic of the": "CD",
        "democratic republic of the congo":"CD",
        "cote d'ivoire":                   "CI",
        "ivory coast":                     "CI",
        "trinidad and tobago":             "TT",
        "saint kitts and nevis":           "KN",
        "antigua and barbuda":             "AG",
        "bosnia and herzegovina":          "BA",
        "saint vincent and the grenadines":"VC",
        "turks and caicos islands":        "TC",
    ]
}

// MARK: - Country card

private struct CountryCard: View {
    let country: NamedCount
    let action: () -> Void
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(CountryFlag.emoji(for: country.name))
                    .font(.system(size: 22))

                Text(CountryFlag.displayName(for: country.name))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(colors.fg)
                    .lineLimit(1)

                Spacer()

                Text(country.stationcount.formatted())
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
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contentShape(Rectangle())
    }
}
