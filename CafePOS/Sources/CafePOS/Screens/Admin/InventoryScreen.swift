import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct InventoryScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Inventory",
            message: "shippingbox — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
    }
}
