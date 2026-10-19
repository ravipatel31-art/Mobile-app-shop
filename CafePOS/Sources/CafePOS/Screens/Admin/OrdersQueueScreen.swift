import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct OrdersQueueScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Orders",
            message: "list.bullet.rectangle — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}
