import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct ReportsScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Reports",
            message: "chart.line.uptrend.xyaxis — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
    }
}
