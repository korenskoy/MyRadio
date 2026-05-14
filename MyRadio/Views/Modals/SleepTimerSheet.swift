import SwiftUI

struct SleepTimerSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var sliderValue: Double = Self.sliderFromMinutes(30)

    private var sleepTimer: SleepTimerService { state.sleepTimer }

    private var selectedMinutes: Double {
        Self.snapMinutes(Self.minutesFromSlider(sliderValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            content
            divider
            footer
        }
        .frame(width: 380)
        .background(colors.bgPanel)
        .onAppear {
            if sleepTimer.totalDuration > 0 {
                sliderValue = Self.sliderFromMinutes(sleepTimer.totalDuration / 60)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppLayout.rMd)
                    .fill(colors.accent.strong.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colors.accent.strong)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep timer")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(colors.fg)
                Text("Pause after…")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.fg3)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(colors.bgPill))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 24) {
            ringView
            if !sleepTimer.isActive {
                sliderView
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(colors.bgInput, lineWidth: 14)
                .overlay(
                    Circle().stroke(colors.border, lineWidth: 0.5)
                )
            Circle()
                .trim(from: 0, to: sleepTimer.isActive ? CGFloat(1.0 - sleepTimer.progress) : 1.0)
                .stroke(
                    colors.accent.strong,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: sleepTimer.progress)
            VStack(spacing: 4) {
                Text(centerTimeText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.fg)
                    .monospacedDigit()
                Text("until pause")
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
            }
        }
        .frame(width: 210, height: 210)
    }

    private var sliderView: some View {
        VStack(spacing: 8) {
            Slider(value: $sliderValue)
                .tint(colors.accent.strong)
            HStack {
                Text(verbatim: DurationLabel.narrow(minutes: 5)).font(Typography.tag).foregroundStyle(colors.fg3)
                Spacer()
                Text(verbatim: DurationLabel.narrow(minutes: 60)).font(Typography.tag).foregroundStyle(colors.fg3)
                Spacer()
                Text(verbatim: DurationLabel.narrow(minutes: 120)).font(Typography.tag).foregroundStyle(colors.fg3)
                Spacer()
                Text(verbatim: DurationLabel.narrow(minutes: 240)).font(Typography.tag).foregroundStyle(colors.fg3)
                Spacer()
                Text(verbatim: DurationLabel.narrow(minutes: 480)).font(Typography.tag).foregroundStyle(colors.fg3)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(SheetSecondaryButtonStyle(colors: colors))
            Spacer()
            if sleepTimer.isActive {
                Button("Cancel timer") {
                    sleepTimer.cancel()
                    dismiss()
                }
                .buttonStyle(SheetDestructiveButtonStyle(colors: colors))
            } else {
                Button("Start timer") {
                    NotificationService.requestAuthorizationIfNeeded()
                    sleepTimer.schedule(minutes: selectedMinutes)
                    dismiss()
                }
                .buttonStyle(SheetPrimaryButtonStyle(colors: colors))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle().fill(colors.border).frame(height: 0.5)
    }

    private var centerTimeText: String {
        sleepTimer.isActive
            ? Self.formatRemaining(sleepTimer.remainingSeconds)
            : Self.formatDuration(selectedMinutes)
    }

    // Piecewise-linear: breakpoints align with tick marks at t = 0, 0.25, 0.5, 0.75, 1
    private static let breakpoints: [(t: Double, m: Double)] = [
        (0.00,   5),
        (0.25,  60),
        (0.50, 120),
        (0.75, 240),
        (1.00, 480)
    ]

    private static func minutesFromSlider(_ t: Double) -> Double {
        for i in 0..<breakpoints.count - 1 {
            let lo = breakpoints[i], hi = breakpoints[i + 1]
            if t <= hi.t {
                let frac = (t - lo.t) / (hi.t - lo.t)
                return lo.m + frac * (hi.m - lo.m)
            }
        }
        return 480
    }

    private static func sliderFromMinutes(_ m: Double) -> Double {
        for i in 0..<breakpoints.count - 1 {
            let lo = breakpoints[i], hi = breakpoints[i + 1]
            if m <= hi.m {
                let frac = (m - lo.m) / (hi.m - lo.m)
                return lo.t + frac * (hi.t - lo.t)
            }
        }
        return 1.0
    }

    private static func snapMinutes(_ raw: Double) -> Double {
        let step: Double = raw < 60 ? 5 : raw < 120 ? 15 : 30
        return max(5, min(480, (raw / step).rounded() * step))
    }

    private static func formatDuration(_ minutes: Double) -> String {
        DurationLabel.narrow(minutes: Int(minutes.rounded()))
    }

    private static func formatRemaining(_ seconds: TimeInterval) -> String {
        DurationLabel.narrow(seconds: seconds)
    }
}

// MARK: - Button Styles

private struct SheetSecondaryButtonStyle: ButtonStyle {
    let colors: AppColors
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body)
            .foregroundStyle(colors.fg2)
            .frame(height: 32)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .fill(colors.bgInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.rSm)
                            .stroke(colors.borderStrong, lineWidth: 0.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct SheetPrimaryButtonStyle: ButtonStyle {
    let colors: AppColors
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colors.accent.fg)
            .frame(height: 32)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .fill(colors.accent.strong)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SheetDestructiveButtonStyle: ButtonStyle {
    let colors: AppColors
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 32)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .fill(colors.statusErr)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
