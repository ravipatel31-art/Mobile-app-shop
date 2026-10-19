import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct DashboardScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Dashboard",
            message: "chart.bar — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}
