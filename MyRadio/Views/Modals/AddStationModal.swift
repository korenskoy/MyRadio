import SwiftUI
import AVFoundation

struct AddStationModal: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    @State private var streamURL = ""
    @State private var name = ""
    @State private var country = ""
    @State private var language = ""
    @State private var tags = ""
    @State private var bitrateText = ""

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var testTask: Task<Void, Never>?

    private var canAdd: Bool {
        !streamURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Station")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.fg)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            // Form
            VStack(spacing: 14) {
                fieldRow(label: "Stream URL", placeholder: "https://...", text: $streamURL, required: true)
                fieldRow(label: "Name", placeholder: "Station name", text: $name, required: true)

                Divider()
                    .overlay(colors.border)

                fieldRow(label: "Country", placeholder: "e.g. Germany", text: $country)
                fieldRow(label: "Language", placeholder: "e.g. English", text: $language)
                fieldRow(label: "Tags", placeholder: "jazz, chill, lo-fi", text: $tags)
                fieldRow(label: "Bitrate", placeholder: "128", text: $bitrateText, isNumeric: true)
            }
            .padding(.horizontal, 24)

            // Test stream
            HStack(spacing: 10) {
                Button(action: testStream) {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11))
                        }
                        Text(isTesting
                             ? String(localized: "Testing...")
                             : String(localized: "Test Stream"))
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(colors.fg)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(colors.bgInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.rSm)
                            .strokeBorder(colors.borderStrong, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
                }
                .buttonStyle(.plain)
                .disabled(streamURL.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)

                if let result = testResult {
                    HStack(spacing: 4) {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text(result.message)
                            .font(Typography.meta)
                    }
                    .foregroundStyle(result.isSuccess ? colors.statusOk : colors.statusErr)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
                .frame(height: 24)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    cancelTest()
                    state.showAddStation = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.fg2)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(colors.bgInput)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.rSm)
                        .strokeBorder(colors.borderStrong, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))

                Button(action: addStation) {
                    Text("Add")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(canAdd ? colors.accent.fg : colors.fg3)
                        .padding(.horizontal, 20)
                        .frame(height: 32)
                        .background(canAdd ? colors.accent.accent : colors.bgInput)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppLayout.rSm)
                                .strokeBorder(canAdd ? colors.accent.strong : colors.borderStrong, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .background(colors.bgPanel)
        .onDisappear { cancelTest() }
    }

    // MARK: - Field row

    private func fieldRow(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        required: Bool = false,
        isNumeric: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(colors.fg2)
                if required {
                    Text(verbatim: "*")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(colors.statusErr)
                }
            }
            .frame(width: 80, alignment: .trailing)

            TextField(placeholder, text: text)
                .font(Typography.searchInput)
                .foregroundStyle(colors.fg)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(colors.bgInput)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.rSm)
                        .strokeBorder(colors.borderStrong, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
                .onChange(of: text.wrappedValue) { _, newValue in
                    if isNumeric {
                        text.wrappedValue = newValue.filter { $0.isNumber }
                    }
                }
        }
    }

    // MARK: - Actions

    private func addStation() {
        guard canAdd else { return }
        cancelTest()

        let bitrate = Int(bitrateText)
        // Trim BEFORE the empty check, otherwise a whitespace-only field is saved
        // as "" instead of nil.
        let trimmedCountry  = country.trimmingCharacters(in: .whitespaces)
        let trimmedLanguage = language.trimmingCharacters(in: .whitespaces)
        let trimmedTags     = tags.trimmingCharacters(in: .whitespaces)
        state.addCustomStation(
            name: name.trimmingCharacters(in: .whitespaces),
            url: streamURL.trimmingCharacters(in: .whitespaces),
            country: trimmedCountry.isEmpty ? nil : trimmedCountry,
            language: trimmedLanguage.isEmpty ? nil : trimmedLanguage,
            tags: trimmedTags.isEmpty ? nil : trimmedTags,
            bitrate: bitrate
        )
        state.showAddStation = false
    }

    private func testStream() {
        let urlString = streamURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlString) else {
            testResult = TestResult(isSuccess: false, message: String(localized: "Invalid URL"))
            return
        }

        isTesting = true
        testResult = nil

        testTask = Task { @MainActor in
            let result = await StreamTester.test(url: url)
            guard !Task.isCancelled else { return }
            testResult = result
            isTesting = false
        }
    }

    private func cancelTest() {
        testTask?.cancel()
        testTask = nil
        isTesting = false
    }
}

// MARK: - Test result

struct TestResult {
    let isSuccess: Bool
    let message: String
}

// MARK: - Stream tester

private enum StreamTester {
    static func test(url: URL) async -> TestResult {
        let asset = AVURLAsset(url: url)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player.volume = 0

        player.play()

        // Wait up to 8 seconds for playback to start
        for _ in 0..<16 {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled {
                player.pause()
                return TestResult(isSuccess: false, message: String(localized: "Cancelled"))
            }
            // `rate > 0` is true the moment we call play(), even while buffering —
            // only `.playing` means audio is actually flowing.
            if player.timeControlStatus == .playing {
                player.pause()
                return TestResult(isSuccess: true, message: String(localized: "Stream OK"))
            }
            if let error = player.currentItem?.error {
                player.pause()
                return TestResult(isSuccess: false, message: error.localizedDescription)
            }
        }

        player.pause()
        return TestResult(isSuccess: false, message: String(localized: "Timeout"))
    }
}
