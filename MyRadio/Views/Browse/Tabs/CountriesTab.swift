import SwiftUI
import RadioBrowserKit

struct CountriesTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @State private var sortByName = false
    @State private var selectedCountry: NamedCount?
    @State private var isLoadingStations = false
    @State private var countryLoadTask: Task<Void, Never>?
    @State private var filterText = ""

    private var totalStations: Int {
        state.apiCountries.reduce(0) { $0 + $1.stationcount }
    }

    private var sortedCountries: [NamedCount] {
        let filtered: [NamedCount]
        if filterText.isEmpty {
            filtered = state.apiCountries
        } else {
            filtered = state.apiCountries.filter {
                CountryFlag.displayName(for: $0.name).localizedCaseInsensitiveContains(filterText)
                    || $0.name.localizedCaseInsensitiveContains(filterText)
            }
        }
        if sortByName {
            return filtered.sorted {
                CountryFlag.displayName(for: $0.name)
                    .localizedCaseInsensitiveCompare(CountryFlag.displayName(for: $1.name)) == .orderedAscending
            }
        }
        return filtered
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
        ToolbarRow {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 28)
                TextField("Filter countries...", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(colors.fg)
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
            Spacer()
            Text("\(state.apiCountries.count) countries · \(totalStations.formatted()) stations")
                .font(Typography.meta)
                .foregroundStyle(colors.fg3)
            BrowseButton(label: nil, icon: "arrow.clockwise", style: .ghost) {
                Task { await state.reloadCountries() }
            }
        }

        if state.apiCountries.isEmpty {
            ContentUnavailableView("Loading countries…", systemImage: "globe")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            let rows = stride(from: 0, to: sortedCountries.count, by: 3).map { i in
                (0..<3).compactMap { j in i + j < sortedCountries.count ? sortedCountries[i + j] : nil }
            }
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row) { country in
                            CountryCard(country: country) { onSelect(country) }
                        }
                        ForEach(0..<(3 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func onSelect(_ country: NamedCount) {
        selectedCountry = country
        isLoadingStations = true
        countryLoadTask?.cancel()
        countryLoadTask = Task {
            await state.loadStationsForCountry(country.name)
            guard !Task.isCancelled, selectedCountry?.name == country.name else { return }
            isLoadingStations = false
        }
    }

    // MARK: - Country detail

    @ViewBuilder
    private func countryDetail(_ country: NamedCount) -> some View {
        ZStack {
            // Center: flag + name
            HStack(spacing: 6) {
                Text(CountryFlag.emoji(for: country.name))
                    .font(.system(size: 16))
                Text(CountryFlag.displayName(for: country.name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colors.fg)
            }

            // Left: back button
            HStack {
                Button {
                    selectedCountry = nil
                    state.selectedCountryCode = nil
                    state.countryStations = []
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(colors.accent.accent)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // Right: station count
            HStack {
                Spacer()
                Text("\(state.countryStations.count) stations")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
            }
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

    /// Locale-aware display name. The API often sends long/awkward English forms
    /// ("The Russian Federation"); we resolve them to ISO codes and then ask
    /// `Locale.current` for the canonical display name so country lists translate
    /// alongside the rest of the UI.
    static func displayName(for name: String) -> String {
        guard let code = isoCode(for: name) else { return name }
        let locale = Locale.current
        // macOS 13+ returns "China mainland" for CN in English; preserve our clean
        // English override only for English locales — other languages already get
        // a clean native name (e.g. "Китай", "中国").
        if code == "CN",
           locale.language.languageCode?.identifier == "en",
           let clean = displayOverrides[code] {
            return clean
        }
        return locale.localizedString(forRegionCode: code) ?? name
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

    // Display name overrides for cases where the locale returns unwanted strings
    // (e.g. macOS 13+ returns "China mainland" for CN instead of "China").
    private static let displayOverrides: [String: String] = [
        "CN": "China",
    ]

    // Known API names that don't match locale strings even after stripping "The".
    private static let aliases: [String: String] = [
        // China (macOS 13+ locale returns "China mainland", API sends "China")
        "china":                                            "CN",
        // Russia
        "russian federation":                               "RU",
        // USA
        "united states of america":                         "US",
        // UK (long official name from API)
        "united kingdom of great britain and northern ireland": "GB",
        // Korea
        "korea, republic of":                               "KR",
        "republic of korea":                                "KR",
        "south korea":                                      "KR",
        "korea, democratic people's republic of":           "KP",
        "democratic people's republic of korea":            "KP",
        "democratic peoples republic of korea":             "KP",
        // Iran
        "iran, islamic republic of":                        "IR",
        "islamic republic of iran":                         "IR",
        // Syria
        "syrian arab republic":                             "SY",
        // Vietnam
        "viet nam":                                         "VN",
        // Czechia
        "czech republic":                                   "CZ",
        // Moldova
        "republic of moldova":                              "MD",
        // Tanzania
        "tanzania, united republic of":                     "TZ",
        // Taiwan
        "taiwan, province of china":                        "TW",
        // Bolivia
        "bolivia, plurinational state of":                  "BO",
        // Venezuela
        "venezuela, bolivarian republic of":                "VE",
        // Micronesia
        "micronesia, federated states of":                  "FM",
        "federated states of micronesia":                   "FM",
        // Congo
        "congo, the democratic republic of the":            "CD",
        "democratic republic of the congo":                 "CD",
        "dr congo":                                         "CD",
        "congo":                                            "CG",
        // Côte d'Ivoire (+ API typos)
        "cote d'ivoire":                                    "CI",
        "coted ivoire":                                     "CI",
        "cote d ivoire":                                    "CI",
        "ivory coast":                                      "CI",
        // Palestine (+ API typo "Stete")
        "state of palestine":                               "PS",
        "stete of palestine":                               "PS",
        "palestine":                                        "PS",
        // North Macedonia
        "republic of north macedonia":                      "MK",
        "north macedonia":                                  "MK",
        // Réunion
        "reunion":                                          "RE",
        // Curaçao
        "curacao":                                          "CW",
        // Bonaire
        "bonaire":                                          "BQ",
        "bonaire, sint eustatius and saba":                 "BQ",
        // Falkland Islands (API includes "Malvinas")
        "falkland islands malvinas":                        "FK",
        "falkland islands (malvinas)":                      "FK",
        // British Indian Ocean Territory
        "british indian ocean territory":                   "IO",
        // Myanmar
        "myanmar":                                          "MM",
        // Brunei
        "brunei darussalam":                                "BN",
        // Laos
        "lao people's democratic republic":                 "LA",
        "lao peoples democratic republic":                  "LA",
        "laos":                                             "LA",
        // Cabo Verde
        "cabo verde":                                       "CV",
        // Åland Islands
        "aland islands":                                    "AX",
        // Saint Pierre and Miquelon (API typo "Miquerlon")
        "saint pierre and miquelon":                        "PM",
        "saint pierre and miquerlon":                       "PM",
        // São Tomé and Príncipe (API typo "Pricipe")
        "sao tome and principe":                            "ST",
        "sao tome and pricipe":                             "ST",
        // Guinea-Bissau
        "guinea-bissau":                                    "GW",
        "guinea bissau":                                    "GW",
        // Saint Helena (API uses long name with typo "Cucha")
        "saint helena, ascension and tristan da cunha":     "SH",
        "ascension and tristan da cucha saint helena":      "SH",
        "saint helena":                                     "SH",
        // Cocos (Keeling) Islands
        "cocos (keeling) islands":                          "CC",
        "cocos keeling islands":                            "CC",
        // Svalbard and Jan Mayen
        "svalbard and jan mayen":                           "SJ",
        // Venezuela (alternate word order)
        "bolivarian republic of venezuela":                 "VE",
        // Taiwan
        "taiwan, republic of china":                        "TW",
        "republic of china":                                "TW",
        // Holy See / Vatican
        "holy see":                                         "VA",
        "vatican":                                          "VA",
        // US Minor Outlying Islands
        "united states minor outlying islands":             "UM",
        // Timor-Leste (no hyphen in API)
        "timor leste":                                      "TL",
        "east timor":                                       "TL",
        // Tanzania (alternate word order)
        "united republic of tanzania":                      "TZ",
        // US Virgin Islands
        "us virgin islands":                                "VI",
        "u.s. virgin islands":                              "VI",
        "united states virgin islands":                     "VI",
        // Wallis and Futuna
        "wallis and futuna":                                "WF",
        "wallis & futuna":                                  "WF",
        // Saint Helena (alternate word order with correct spelling)
        "ascension and tristan da cunha saint helena":      "SH",
        // Misc
        "trinidad and tobago":                              "TT",
        "saint kitts and nevis":                            "KN",
        "antigua and barbuda":                              "AG",
        "bosnia and herzegovina":                           "BA",
        "saint vincent and the grenadines":                 "VC",
        "turks and caicos islands":                         "TC",
        "saint lucia":                                      "LC",
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
