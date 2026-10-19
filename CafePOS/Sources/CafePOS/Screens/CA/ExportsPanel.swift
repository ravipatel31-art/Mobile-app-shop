import SwiftUI

/// Placeholder — accounting exports (Tally/GSTR) not ported yet.
struct ExportsPanel: View {
    var body: some View {
        EmptyStateArt(
            title: "Exports",
            message: "Tally XML/CSV & GSTR exports not ported yet.",
            icon: "square.and.arrow.up"
        )
        .navigationTitle("Exports")
        .navigationBarTitleDisplayMode(.inline)
    }
}
