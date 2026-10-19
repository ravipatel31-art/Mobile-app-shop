import SwiftUI

/// Placeholder — full port pending.
struct KitchenDisplayScreen: View {
    var showCompleted: Bool
    var body: some View {
        EmptyStateArt(
            title: showCompleted ? "Completed" : "Active orders",
            message: "Kitchen display not ported yet.",
            icon: "flame"
        )
        .navigationTitle(showCompleted ? "Completed" : "Kitchen Orders")
        .navigationBarTitleDisplayMode(.inline)
    }
}
