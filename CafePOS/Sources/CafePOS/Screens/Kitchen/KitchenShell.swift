import SwiftUI

/// Kitchen display shell — active vs ready orders.
struct KitchenShell: View {
    @EnvironmentObject private var auth: AuthState
    @State private var index = 0
    private let titles = ["Kitchen Orders", "Completed"]

    var body: some View {
        TabView(selection: $index) {
            KitchenDisplayScreen(showCompleted: false)
                .tabItem { Label("Active", systemImage: "flame") }.tag(0)
            KitchenDisplayScreen(showCompleted: true)
                .tabItem { Label("Ready", systemImage: "checkmark.circle") }.tag(1)
        }
        .navigationTitle(titles[index])
        .toolbar {
            ShellAppBar(
                title: titles[index],
                userName: auth.name ?? auth.username ?? "Kitchen",
                onLogout: { Task { await auth.logout() } },
                onAsk: {}
            )
        }
    }
}
