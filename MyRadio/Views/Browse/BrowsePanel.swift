import SwiftUI

// Этап 2: заполняется полным UI
struct BrowsePanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.appColors) private var colors

    var body: some View {
        ZStack {
            colors.bgPanel2
            Text("Browse")
                .foregroundStyle(colors.fg3)
        }
    }
}
