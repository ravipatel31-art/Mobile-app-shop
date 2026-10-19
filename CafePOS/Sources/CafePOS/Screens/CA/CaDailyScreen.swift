import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct CaDailyScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Daily Sales",
            message: "calendar — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Daily Sales")
        .navigationBarTitleDisplayMode(.inline)
    }
}
