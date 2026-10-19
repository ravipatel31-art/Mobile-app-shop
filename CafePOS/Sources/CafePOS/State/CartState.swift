import SwiftUI

/// The in-progress order cart. Mirrors Dart's CartState (ChangeNotifier).
@MainActor
final class CartState: ObservableObject {
    @Published private(set) var lines: [CartLine] = []
    @Published var customerName: String?
    @Published var customerPhone: String?

    /// Bumped when the set of tables changes so the grid can refresh.
    @Published private(set) var tablesTick = 0

    var isEmpty: Bool { lines.isEmpty }
    var count: Int { lines.reduce(0) { $0 + $1.qty } }
    var total: Int { lines.reduce(0) { $0 + $1.lineTotal } }
    var itemsJson: [JSON] { lines.map { $0.toOrderItemJson() } }

    func tablesChanged() { tablesTick += 1 }

    func setCustomerInfo(name: String?, phone: String?) {
        customerName = name
        customerPhone = phone
    }

    func add(_ item: MenuItem, options: [SelectedOption], qty: Int) {
        lines.append(CartLine(item: item, selectedOptions: options, qty: qty))
    }

    func setQty(_ index: Int, _ qty: Int) {
        guard index >= 0 && index < lines.count else { return }
        if qty <= 0 { lines.remove(at: index) } else { lines[index].qty = qty }
    }

    func removeAt(_ index: Int) {
        guard index >= 0 && index < lines.count else { return }
        lines.remove(at: index)
    }

    func removeLine(_ line: CartLine) {
        lines.removeAll { $0 === line }
    }

    func clear() {
        lines.removeAll()
        customerName = nil
        customerPhone = nil
    }

    func buildOrderPayload(name: String? = nil, phone: String? = nil,
                           pickupType: String = "table", notes: String = "",
                           tableNumber: String? = nil, paymentMethod: String = "cash") -> JSON {
        let resolvedName = name ?? customerName ?? (tableNumber != nil ? "Table \(tableNumber!)" : "Guest")
        let resolvedPhone = phone ?? customerPhone
        var body: JSON = [
            "customer": ["name": resolvedName],
            "pickup_type": pickupType,
            "notes": notes,
            "payment_method": paymentMethod,
            "items": lines.map { $0.toOrderItemJson() },
        ]
        if let resolvedPhone, !resolvedPhone.isEmpty {
            body["customer"] = ["name": resolvedName, "phone": resolvedPhone]
        }
        if let tableNumber { body["table_number"] = tableNumber }
        return body
    }
}
