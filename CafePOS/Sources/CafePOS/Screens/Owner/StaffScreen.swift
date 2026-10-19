import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct StaffScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Staff",
            message: "person.2 — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
    }
}
