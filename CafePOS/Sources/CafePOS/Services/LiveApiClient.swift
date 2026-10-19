import Foundation

/// URLSession-backed implementation of ApiServicing. Talks to the Flask
/// backend. Timeouts mirror the Dart client (5s normal, longer for AI calls).
final class LiveApiClient: ApiServicing {
    var token: String?

    private let session: URLSession
    private let normalTimeout: TimeInterval = 5
    private let aiTimeout: TimeInterval = 40
    private let askTimeout: TimeInterval = 75

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func url(_ path: String, _ query: [String: String?] = [:]) throws -> URL {
        guard var comps = URLComponents(string: AppConfig.baseUrl + path) else {
            throw ApiException("Invalid URL: \(path)")
        }
        let cleaned = query.compactMapValues { $0 }
        if !cleaned.isEmpty {
            comps.queryItems = cleaned.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let u = comps.url else { throw ApiException("Invalid URL: \(path)") }
        return u
    }

    private var headers: [String: String] {
        var h = ["Content-Type": "application/json"]
        if let token { h["Authorization"] = "Bearer \(token)" }
        return h
    }

    private func decode(_ data: Data, _ response: URLResponse?) async throws -> Any {
        let http = response as? HTTPURLResponse
        let obj: Any? = data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data)
        if let http, (200..<300).contains(http.statusCode) {
            return obj ?? NSNull()
        }
        var msg = "Request failed (\(http?.statusCode ?? 0))"
        if let m = (obj as? JSON)?["error"] as? String { msg = m }
        throw ApiException(msg, statusCode: http?.statusCode)
    }

    private func request(_ method: String, _ path: String,
                         _ body: Any? = nil, _ query: [String: String?] = [:],
                         timeout: TimeInterval? = nil) async throws -> Any {
        let t = timeout ?? normalTimeout
        var req = URLRequest(url: try url(path, query))
        req.httpMethod = method
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        req.timeoutInterval = t
        do {
            let (data, resp) = try await session.data(for: req)
            return try await decode(data, resp)
        } catch let e as ApiException {
            throw e
        } catch {
            throw ApiException("Cannot reach the server. Is the backend running?")
        }
    }

    private func get(_ path: String, _ query: [String: String?] = [:]) async throws -> Any {
        try await request("GET", path, nil, query)
    }
    private func send(_ method: String, _ path: String, _ body: Any?,
                      timeout: TimeInterval? = nil) async throws -> Any {
        try await request(method, path, body, [:], timeout: timeout)
    }

    // ---- Auth ----
    func login(_ username: String, _ password: String, tenant: String?) async throws -> JSON {
        var body: JSON = ["username": username, "password": password]
        if let tenant, !tenant.isEmpty { body["tenant"] = tenant }
        return try await send("POST", "/auth/login", body) as? JSON ?? [:]
    }
    func register(_ username: String, _ password: String, _ name: String) async throws {
        _ = try await send("POST", "/auth/register",
                           ["username": username, "password": password, "name": name])
    }

    // ---- Menu ----
    func fetchMenu(category: String?) async throws -> [MenuItem] {
        let data = try await get("/menu", ["category": category])
        return (data as? [JSON] ?? []).map(MenuItem.init(json:))
    }
    func fetchCategories() async throws -> [String] {
        let data = try await get("/categories")
        return data as? [String] ?? []
    }

    // ---- AI ----
    func fetchRecommendations(_ cart: [CartLine]) async throws -> [Suggestion] {
        let body: JSON = ["cart": cart.map { ["item_id": $0.item.id, "qty": $0.qty] }]
        let data = try await send("POST", "/recommend", body, timeout: aiTimeout) as? JSON ?? [:]
        return data.jsonArray("suggestions").map(Suggestion.init(json:))
    }
    func askQuestion(_ question: String) async throws -> AskResult {
        let data = try await send("POST", "/ask", ["question": question], timeout: askTimeout) as? JSON ?? [:]
        return AskResult(json: data)
    }
    func executeAction(_ action: String, _ args: JSON) async throws -> JSON {
        try await send("POST", "/ask/execute", ["action": action, "args": args],
                       timeout: aiTimeout) as? JSON ?? [:]
    }

    // ---- Orders ----
    func placeOrder(_ payload: JSON) async throws -> CafeOrder {
        CafeOrder(json: try await send("POST", "/orders", payload) as? JSON ?? [:])
    }
    func fetchOrder(_ id: String) async throws -> CafeOrder {
        CafeOrder(json: try await get("/orders/\(id)") as? JSON ?? [:])
    }
    func fetchOrders(status: String?, date: String?, takenBy: String?) async throws -> [CafeOrder] {
        let data = try await get("/orders", ["status": status, "date": date, "taken_by": takenBy])
        return (data as? [JSON] ?? []).map(CafeOrder.init(json:))
    }
    func updateOrderStatus(_ id: String, _ status: String, paid: Bool,
                           paymentMethod: String?, payments: [JSON]?) async throws -> CafeOrder {
        var body: JSON = ["status": status]
        if paid { body["paid"] = true }
        if let paymentMethod { body["payment_method"] = paymentMethod }
        if let payments, !payments.isEmpty { body["payments"] = payments }
        return CafeOrder(json: try await send("PATCH", "/orders/\(id)/status", body) as? JSON ?? [:])
    }
    func reopenOrder(_ id: String) async throws -> CafeOrder {
        CafeOrder(json: try await send("POST", "/orders/\(id)/reopen", [:]) as? JSON ?? [:])
    }
    func addOrderItems(_ id: String, _ items: [JSON]) async throws -> CafeOrder {
        CafeOrder(json: try await send("POST", "/orders/\(id)/items", ["items": items]) as? JSON ?? [:])
    }

    // ---- Tables ----
    func fetchTables() async throws -> [CafeTable] {
        let data = try await get("/tables")
        return (data as? [JSON] ?? []).map(CafeTable.init(json:))
    }
    func freeTable(_ number: String) async throws {
        _ = try await send("POST", "/tables/\(number)/free", [:])
    }
    func addTable(number: Int?) async throws -> CafeTable {
        var body: JSON = [:]
        if let number { body["number"] = number }
        return CafeTable(json: try await send("POST", "/admin/tables", body) as? JSON ?? [:])
    }
    func removeTable(_ number: String) async throws {
        _ = try await send("DELETE", "/admin/tables/\(number)", nil)
    }

    // ---- Staff ----
    func fetchStaff() async throws -> [StaffMember] {
        let data = try await get("/admin/staff")
        return (data as? [JSON] ?? []).map(StaffMember.init(json:))
    }
    func approveStaff(_ username: String) async throws {
        _ = try await send("POST", "/admin/staff/\(username)/approve", [:])
    }
    func removeStaff(_ username: String) async throws {
        _ = try await send("DELETE", "/admin/staff/\(username)", nil)
    }
    func createStaff(_ username: String, _ password: String, _ name: String) async throws {
        _ = try await send("POST", "/admin/staff",
                           ["username": username, "password": password, "name": name])
    }

    // ---- Reports / billing ----
    func dailyReport(_ date: String) async throws -> SalesSummary {
        SalesSummary(json: try await get("/admin/reports/daily", ["date": date]) as? JSON ?? [:])
    }
    func rangeReport(_ from: String, _ to: String) async throws -> [SalesSummary] {
        let data = try await get("/admin/reports/range", ["from": from, "to": to])
        return (data as? [JSON] ?? []).map(SalesSummary.init(json:))
    }
    func fetchBilling(date: String?) async throws -> BillingSummary {
        BillingSummary(json: try await get("/admin/billing", ["date": date]) as? JSON ?? [:])
    }
    func markOrderPaid(_ id: String) async throws -> CafeOrder {
        CafeOrder(json: try await send("POST", "/admin/billing/\(id)/paid", [:]) as? JSON ?? [:])
    }

    // ---- Menu management ----
    func createMenuItem(_ payload: JSON) async throws -> MenuItem {
        MenuItem(json: try await send("POST", "/admin/menu", payload) as? JSON ?? [:])
    }
    func setAvailability(_ id: String, _ available: Bool) async throws -> MenuItem {
        MenuItem(json: try await send("PATCH", "/admin/menu/\(id)/availability",
                                      ["available": available]) as? JSON ?? [:])
    }
    func updateMenuItem(_ id: String, _ payload: JSON) async throws -> MenuItem {
        MenuItem(json: try await send("PUT", "/admin/menu/\(id)", payload) as? JSON ?? [:])
    }
    func deleteMenuItem(_ id: String) async throws {
        _ = try await send("DELETE", "/admin/menu/\(id)", nil)
    }

    // ---- Inventory ----
    func fetchInventory() async throws -> [InventoryItem] {
        let data = try await get("/admin/inventory")
        return (data as? [JSON] ?? []).map(InventoryItem.init(json:))
    }
    func createInventoryItem(_ payload: JSON) async throws -> InventoryItem {
        InventoryItem(json: try await send("POST", "/admin/inventory", payload) as? JSON ?? [:])
    }
    func updateInventoryItem(_ id: String, _ payload: JSON) async throws -> InventoryItem {
        InventoryItem(json: try await send("PUT", "/admin/inventory/\(id)", payload) as? JSON ?? [:])
    }
    func restockItem(_ id: String, _ quantity: Int) async throws -> InventoryItem {
        InventoryItem(json: try await send("POST", "/admin/inventory/\(id)/restock",
                                           ["quantity": quantity]) as? JSON ?? [:])
    }
    func deleteInventoryItem(_ id: String) async throws {
        _ = try await send("DELETE", "/admin/inventory/\(id)", nil)
    }

    // ---- Tenant branding ----
    func fetchTenantConfig(_ slug: String) async throws -> JSON {
        try await get("/public/\(slug)/config") as? JSON ?? [:]
    }
}
