import SwiftUI

struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.fg)
                .tracking(-0.1)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(Typography.meta)
                    .foregroundStyle(colors.fg3)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

struct ToolbarRow<Content: View>: View {
    var subtitle: LocalizedStringKey? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
            if let subtitle {
                Spacer()
                Text(subtitle)
                    .font(Typography.meta)
                    .foregroundStyle(Color(hex: 0x97948A))
            }
        }
        .padding(.bottom, 14)
    }
}

struct BrowseButton: View {
    let label: LocalizedStringKey?
    var icon: String? = nil
    var style: ButtonKind = .normal
    var action: () -> Void = {}
    @Environment(\.appColors) private var colors
    @State private var hovered = false

    enum ButtonKind { case normal, primary, ghost }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                if let label {
                    Text(label)
                        .font(.system(size: 12.5, weight: .medium))
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, label == nil ? 8 : 12)
            .frame(height: 32)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.rSm)
                    .strokeBorder(borderColor, lineWidth: style == .ghost ? 0 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.rSm))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return colors.accent.fg
        case .ghost: return hovered ? colors.fg : colors.fg2
        case .normal: return colors.fg
        }
    }

    private var bgColor: Color {
        switch style {
        case .primary: return hovered ? colors.accent.strong : colors.accent.accent
        case .ghost: return hovered ? colors.bgHover : .clear
        case .normal: return hovered ? colors.bgHover : colors.bgInput
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return colors.accent.strong
        case .ghost: return .clear
        case .normal: return colors.borderStrong
        }
    }
}
