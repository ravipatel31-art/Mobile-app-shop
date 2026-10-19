import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct StaffOrdersScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Order Queue",
            message: "list.bullet.rectangle — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Order Queue")
        .navigationBarTitleDisplayMode(.inline)
    }
}
