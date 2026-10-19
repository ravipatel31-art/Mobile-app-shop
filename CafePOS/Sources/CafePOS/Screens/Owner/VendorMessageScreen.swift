import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct VendorMessageScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Vendors",
            message: "storefront — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Vendors")
        .navigationBarTitleDisplayMode(.inline)
    }
}
