import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct GrowthScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Growth",
            message: "trendingup — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Growth")
        .navigationBarTitleDisplayMode(.inline)
    }
}
