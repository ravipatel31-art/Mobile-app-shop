import SwiftUI

/// Staff container: tables grid, shared order queue, own history.
struct StaffShell: View {
    @EnvironmentObject private var auth: AuthState
    @State private var index = 0
    private let titles = ["Tables", "Order Queue", "History"]

    var body: some View {
        TabView(selection: $index) {
            TablesGridScreen().tabItem { Label("Tables", systemImage: "table.furniture") }.tag(0)
            StaffOrdersScreen().tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }.tag(1)
            StaffHistoryScreen().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(2)
        }
        .navigationTitle(titles[index])
        .toolbar {
            ShellAppBar(
                title: titles[index],
                userName: auth.name ?? auth.username ?? "Staff",
                onLogout: { Task { await auth.logout() } },
                onAsk: {}
            )
        }
    }
}
