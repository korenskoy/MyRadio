import SwiftUI

// Этап 2: заполняется полным UI
struct DebugPanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            colors.bgDebug
            Text("Debug")
                .font(Typography.monoSm)
                .foregroundStyle(colors.fgDebug2)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(colors.borderDebug)
                .frame(height: 0.5)
        }
    }
}
