import SwiftUI

/// App bar used by every role shell: title, an "Ask AI" button, an optional
/// trailing action (e.g. the owner's "More" menu) and a user menu with logout.
/// Mirrors `shell_app_bar.dart`.
struct ShellAppBar: ToolbarContent {
    let title: String
    let userName: String
    var onLogout: () -> Void
    var onAsk: () -> Void
    /// Optional extra trailing button (e.g. "More").
    var extraIcon: String?
    var onExtra: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(title).font(.system(size: 18, weight: .heavy))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onAsk) { Image(systemName: "sparkles") }
        }
        if let extraIcon, let onExtra {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onExtra) { Image(systemName: extraIcon) }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Text(userName)
                Button(role: .destructive, action: onLogout) {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "person.crop.circle")
            }
        }
    }
}
