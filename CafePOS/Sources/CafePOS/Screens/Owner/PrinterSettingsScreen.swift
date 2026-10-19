import SwiftUI

/// Placeholder — full port pending. Shows the screen title so navigation works.
struct PrinterSettingsScreen: View {
    var body: some View {
        EmptyStateArt(
            title: "Printers",
            message: "printer — this screen is not ported yet.",
            icon: "hammer"
        )
        .navigationTitle("Printers")
        .navigationBarTitleDisplayMode(.inline)
    }
}
