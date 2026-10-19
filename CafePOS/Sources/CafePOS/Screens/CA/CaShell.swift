import SwiftUI

/// Read-only shell for the cafe_ca (chartered accountant) login: daily sales,
/// the day-end Z-report, and the accounting exports. No mutation entry points.
struct CaShell: View {
    @EnvironmentObject private var auth: AuthState
    @State private var index = 0
    private let titles = ["Daily Sales", "Z-Report", "Exports"]

    var body: some View {
        TabView(selection: $index) {
            CaDailyScreen().tabItem { Label("Daily", systemImage: "calendar") }.tag(0)
            CaZReportScreen().tabItem { Label("Z-Report", systemImage: "doc.text") }.tag(1)
            ExportsPanel().tabItem { Label("Exports", systemImage: "square.and.arrow.up") }.tag(2)
        }
        .navigationTitle(titles[index])
        .toolbar {
            ShellAppBar(
                title: titles[index],
                userName: auth.name ?? auth.username ?? "CA",
                onLogout: { Task { await auth.logout() } },
                onAsk: {}
            )
        }
    }
}
