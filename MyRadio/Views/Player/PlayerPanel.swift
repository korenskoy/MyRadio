import SwiftUI

// Этап 2: заполняется полным UI
struct PlayerPanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.bgPanel, colors.bgPanel2],
                startPoint: .top,
                endPoint: .bottom
            )
            Text("Player")
                .foregroundStyle(colors.fg3)
        }
    }
}
