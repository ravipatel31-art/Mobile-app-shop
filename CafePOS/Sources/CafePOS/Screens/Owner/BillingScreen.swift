import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct BillingScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Billing",
            message: "creditcard — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Billing")
        .navigationBarTitleDisplayMode(.inline)
    }
}
