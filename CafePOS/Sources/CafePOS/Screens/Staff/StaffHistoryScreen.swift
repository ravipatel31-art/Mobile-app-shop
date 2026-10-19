import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct StaffHistoryScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "History",
            message: "clock.arrow.circlepath — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
