import SwiftUI

/// Owner container with a bottom tab bar: 5 main tabs + a "More" menu for the
/// less-used screens. Port of `owner_shell.dart`.
struct OwnerShell: View {
    @EnvironmentObject private var auth: AuthState
    @State private var index = 0
    @State private var showMore = false

    private let titles = ["Dashboard", "Orders", "Tables", "Billing", "Vendors"]

    var body: some View {
        TabView(selection: $index) {
            DashboardScreen().tabItem { Label("Sales", systemImage: "chart.bar") }.tag(0)
            OrdersQueueScreen().tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }.tag(1)
            TablesAdminScreen().tabItem { Label("Tables", systemImage: "table.furniture") }.tag(2)
            BillingScreen().tabItem { Label("Billing", systemImage: "creditcard") }.tag(3)
            VendorMessageScreen().tabItem { Label("Vendors", systemImage: "storefront") }.tag(4)
        }
        .navigationTitle(titles[index])
        .toolbar {
            ShellAppBar(
                title: titles[index],
                userName: auth.name ?? auth.username ?? "Owner",
                onLogout: { Task { await auth.logout() } },
                onAsk: {},
                extraIcon: "ellipsis",
                onExtra: { showMore = true }
            )
        }
        .sheet(isPresented: $showMore) { moreSheet }
    }

    private var moreSheet: some View {
        NavigationStack {
            List {
                NavigationLink { ReportsScreen() } label: {
                    moreRow("assessment", "Reports", "Sales analytics & P&L", CafeGradients.coffee)
                }
                NavigationLink { GrowthScreen() } label: {
                    moreRow("trendingup", "Growth", "Loyalty, delivery & table QRs", CafeGradients.mint)
                }
                NavigationLink { ExportsScreen() } label: {
                    moreRow("square.and.arrow.up", "Exports", "Tally XML/CSV & GSTR", CafeGradients.sky)
                }
                NavigationLink { PrinterSettingsScreen() } label: {
                    moreRow("printer", "Printers", "Network · USB · Bluetooth", CafeGradients.sunrise)
                }
                NavigationLink { StaffScreen() } label: {
                    moreRow("person.2", "Staff", "Manage team members", CafeGradients.berry)
                }
                NavigationLink { MenuEditorScreen() } label: {
                    moreRow("menucard", "Menu", "Edit menu items & prices", CafeGradients.peach)
                }
                NavigationLink { InventoryScreen() } label: {
                    moreRow("shippingbox", "Inventory", "Stock tracking", CafeGradients.espresso)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { showMore = false }
            } }
        }
        .presentationDetents([.medium, .large])
    }

    private func moreRow(_ icon: String, _ title: String, _ subtitle: String,
                         _ gradient: LinearGradient) -> some View {
        HStack(spacing: 12) {
            IconChip(icon: icon, gradient: gradient, size: 40, iconSize: 19)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
