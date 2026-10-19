import Foundation

/// In-memory ApiServicing so the app is fully navigable before the Flask
/// backend is reachable. Serves a small canned menu + tables + staff.
final class MockApiClient: ApiServicing {
    var token: String?

    private var menu: [MenuItem]
    private var tables: [CafeTable]
    private var staff: [StaffMember]
    private var orders: [CafeOrder] = []

    init() {
        // A tiny representative menu.
        func item(_ id: String, _ name: String, _ desc: String, _ cat: String,
                  _ price: Int, opts: [OptionGroup] = [], gst: Int = 5) -> MenuItem {
            MenuItem(id: id, name: name, description: desc, category: cat,
                     basePrice: price, imageUrl: nil, available: true,
                     options: opts, gstRate: gst)
        }
        let size = OptionGroup(group: "Size", required: true, multi: false, choices: [
            OptionChoice(label: "Regular", priceDelta: 0),
            OptionChoice(label: "Large", priceDelta: 4000),
        ])
        let milk = OptionGroup(group: "Milk", required: false, multi: false, choices: [
            OptionChoice(label: "Whole", priceDelta: 0),
            OptionChoice(label: "Oat", priceDelta: 2000),
        ])
        self.menu = [
            item("espresso", "Espresso", "Double shot, no milk", "Coffee", 12000),
            item("latte", "Cafe Latte", "Espresso + steamed milk", "Coffee", 18000,
                 opts: [size, milk]),
            item("cappuccino", "Cappuccino", "Espresso + foam", "Coffee", 17000,
                 opts: [size, milk]),
            item("masalachai", "Masala Chai", "Spiced Indian tea", "Tea", 10000),
            item("vegsandwich", "Veg Sandwich", "Grilled veg sandwich", "Food", 9000),
        ]
        self.tables = (1...8).map {
            CafeTable(number: "\($0)", status: "empty", orderId: nil, takenBy: nil)
        }
        self.staff = [
            StaffMember(username: "owner", name: "Owner", role: "owner", status: "approved", lastLogin: nil),
            StaffMember(username: "priya", name: "Priya", role: "staff", status: "approved", lastLogin: nil),
        ]
    }

    private func delay() async { try? await Task.sleep(for: .milliseconds(120)) }

    func login(_ username: String, _ password: String, tenant: String?) async throws -> JSON {
        await delay()
        let role: String
        switch username {
        case "owner": role = "owner"
        case "kitchen": role = "kitchen"
        default: role = "staff"
        }
        token = "mock-token-\(username)"
        return [
            "token": token!, "role": role, "username": username,
            "name": username.capitalized, "tenant": tenant ?? "main",
        ]
    }
    func register(_ username: String, _ password: String, _ name: String) async throws {
        await delay()
    }

    func fetchMenu(category: String?) async throws -> [MenuItem] {
        await delay()
        guard let category, !category.isEmpty else { return menu }
        return menu.filter { $0.category == category }
    }
    func fetchCategories() async throws -> [String] {
        await delay()
        return Array(Set(menu.map(\.category))).sorted()
    }

    func fetchRecommendations(_ cart: [CartLine]) async throws -> [Suggestion] {
        await delay()
        return menu.prefix(2).map {
            Suggestion(item: $0, reason: "Pairs well with your order", unitPrice: $0.basePrice,
                       defaultOptions: [], safeToAutopick: $0.options.allSatisfy { !$0.isRequired })
        }
    }
    func askQuestion(_ question: String) async throws -> AskResult {
        await delay()
        return AskResult(answer: "This is a mock assistant reply.", source: "mock", pendingAction: nil)
    }
    func executeAction(_ action: String, _ args: JSON) async throws -> JSON {
        await delay()
        return ["ok": true]
    }

    func placeOrder(_ payload: JSON) async throws -> CafeOrder {
        await delay()
        let order = CafeOrder(json: [
            "id": "ord-\(orders.count + 1)", "total": 0, "status": "received",
            "customer": payload.json("customer"), "created_at": "",
        ])
        orders.append(order)
        return order
    }
    func fetchOrder(_ id: String) async throws -> CafeOrder {
        await delay()
        return orders.first { $0.id == id } ?? CafeOrder(json: ["id": id, "total": 0])
    }
    func fetchOrders(status: String?, date: String?, takenBy: String?) async throws -> [CafeOrder] {
        await delay()
        return orders
    }
    func updateOrderStatus(_ id: String, _ status: String, paid: Bool,
                           paymentMethod: String?, payments: [JSON]?) async throws -> CafeOrder {
        await delay()
        if let o = orders.first(where: { $0.id == id }) { o.status = status }
        return try await fetchOrder(id)
    }
    func reopenOrder(_ id: String) async throws -> CafeOrder { try await fetchOrder(id) }
    func addOrderItems(_ id: String, _ items: [JSON]) async throws -> CafeOrder { try await fetchOrder(id) }

    func fetchTables() async throws -> [CafeTable] { await delay(); return tables }
    func freeTable(_ number: String) async throws { await delay() }
    func addTable(number: Int?) async throws -> CafeTable {
        await delay()
        let n = number ?? tables.count + 1
        let t = CafeTable(number: "\(n)", status: "empty", orderId: nil, takenBy: nil)
        tables.append(t)
        return t
    }
    func removeTable(_ number: String) async throws {
        await delay()
        tables.removeAll { $0.number == number }
    }

    func fetchStaff() async throws -> [StaffMember] { await delay(); return staff }
    func approveStaff(_ username: String) async throws { await delay() }
    func removeStaff(_ username: String) async throws {
        await delay()
        staff.removeAll { $0.username == username }
    }
    func createStaff(_ username: String, _ password: String, _ name: String) async throws {
        await delay()
        staff.append(StaffMember(username: username, name: name, role: "staff",
                                 status: "pending", lastLogin: nil))
    }

    func dailyReport(_ date: String) async throws -> SalesSummary {
        await delay()
        return SalesSummary(date: date, orderCount: 12, grossSales: 450000,
                            byCategory: ["Coffee": 300000, "Food": 150000],
                            byPayment: ["cash": 250000, "upi": 200000],
                            topItems: [TopItem(name: "Latte", qty: 20, revenue: 360000)])
    }
    func rangeReport(_ from: String, _ to: String) async throws -> [SalesSummary] {
        await delay()
        return [try await dailyReport(from)]
    }
    func fetchBilling(date: String?) async throws -> BillingSummary {
        await delay()
        return BillingSummary(days: [], orderCount: 0, total: 0, paid: 0, unpaid: 0)
    }
    func markOrderPaid(_ id: String) async throws -> CafeOrder { try await fetchOrder(id) }

    func createMenuItem(_ payload: JSON) async throws -> MenuItem {
        await delay()
        let m = MenuItem(json: payload)
        menu.append(m)
        return m
    }
    func setAvailability(_ id: String, _ available: Bool) async throws -> MenuItem {
        await delay()
        return menu.first { $0.id == id } ?? MenuItem(json: ["id": id, "name": ""])
    }
    func updateMenuItem(_ id: String, _ payload: JSON) async throws -> MenuItem {
        await delay()
        return MenuItem(json: payload)
    }
    func deleteMenuItem(_ id: String) async throws {
        await delay()
        menu.removeAll { $0.id == id }
    }

    func fetchInventory() async throws -> [InventoryItem] {
        await delay()
        return [
            InventoryItem(id: "beans", name: "Coffee Beans", quantity: 5, costPrice: 1200,
                          unit: "kg", reorderLevel: 2),
        ]
    }
    func createInventoryItem(_ payload: JSON) async throws -> InventoryItem {
        await delay(); return InventoryItem(json: payload)
    }
    func updateInventoryItem(_ id: String, _ payload: JSON) async throws -> InventoryItem {
        await delay(); return InventoryItem(json: payload)
    }
    func restockItem(_ id: String, _ quantity: Int) async throws -> InventoryItem {
        await delay(); return InventoryItem(json: ["id": id, "name": "", "quantity": quantity])
    }
    func deleteInventoryItem(_ id: String) async throws { await delay() }

    func fetchTenantConfig(_ slug: String) async throws -> JSON {
        await delay()
        return ["display_name": "Bean House Cafe", "kind": "cafe", "bill_footer": "Thank you!"]
    }
}
