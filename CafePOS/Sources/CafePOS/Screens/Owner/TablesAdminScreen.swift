import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct TablesAdminScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Tables",
            message: "table.furniture — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Tables")
        .navigationBarTitleDisplayMode(.inline)
    }
}
