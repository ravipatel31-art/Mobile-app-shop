import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct CaZReportScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Z-Report",
            message: "doc.text — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Z-Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
