import Foundation

/// The subset of the backend API the UI depends on. `LiveApiClient` talks to
/// the Flask backend over URLSession; `MockApiClient` serves canned data so the
/// app builds & runs before any network/backend is wired up.
protocol ApiServicing: AnyObject {
    var token: String? { get set }

    // Auth
    func login(_ username: String, _ password: String, tenant: String?) async throws -> JSON
    func register(_ username: String, _ password: String, _ name: String) async throws

    // Menu (public read)
    func fetchMenu(category: String?) async throws -> [MenuItem]
    func fetchCategories() async throws -> [String]

    // AI
    func fetchRecommendations(_ cart: [CartLine]) async throws -> [Suggestion]
    func askQuestion(_ question: String) async throws -> AskResult
    func executeAction(_ action: String, _ args: JSON) async throws -> JSON

    // Orders
    func placeOrder(_ payload: JSON) async throws -> CafeOrder
    func fetchOrder(_ id: String) async throws -> CafeOrder
    func fetchOrders(status: String?, date: String?, takenBy: String?) async throws -> [CafeOrder]
    func updateOrderStatus(_ id: String, _ status: String, paid: Bool,
                           paymentMethod: String?, payments: [JSON]?) async throws -> CafeOrder
    func reopenOrder(_ id: String) async throws -> CafeOrder
    func addOrderItems(_ id: String, _ items: [JSON]) async throws -> CafeOrder

    // Tables
    func fetchTables() async throws -> [CafeTable]
    func freeTable(_ number: String) async throws
    func addTable(number: Int?) async throws -> CafeTable
    func removeTable(_ number: String) async throws

    // Staff (owner)
    func fetchStaff() async throws -> [StaffMember]
    func approveStaff(_ username: String) async throws
    func removeStaff(_ username: String) async throws
    func createStaff(_ username: String, _ password: String, _ name: String) async throws

    // Reports / billing
    func dailyReport(_ date: String) async throws -> SalesSummary
    func rangeReport(_ from: String, _ to: String) async throws -> [SalesSummary]
    func fetchBilling(date: String?) async throws -> BillingSummary
    func markOrderPaid(_ id: String) async throws -> CafeOrder

    // Menu management (owner)
    func createMenuItem(_ payload: JSON) async throws -> MenuItem
    func setAvailability(_ id: String, _ available: Bool) async throws -> MenuItem
    func updateMenuItem(_ id: String, _ payload: JSON) async throws -> MenuItem
    func deleteMenuItem(_ id: String) async throws

    // Inventory (owner)
    func fetchInventory() async throws -> [InventoryItem]
    func createInventoryItem(_ payload: JSON) async throws -> InventoryItem
    func updateInventoryItem(_ id: String, _ payload: JSON) async throws -> InventoryItem
    func restockItem(_ id: String, _ quantity: Int) async throws -> InventoryItem
    func deleteInventoryItem(_ id: String) async throws

    // Tenant branding (public)
    func fetchTenantConfig(_ slug: String) async throws -> JSON
}
