import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct ExportsScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Exports",
            message: "square.and.arrow.up — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
    }
}
