import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct MenuEditorScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Menu",
            message: "menucard — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
    }
}
