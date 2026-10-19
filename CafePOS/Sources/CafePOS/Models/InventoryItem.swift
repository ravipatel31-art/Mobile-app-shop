import Foundation

final class InventoryItem: Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let costPrice: Int      // whole currency units
    let unit: String
    let purchaseDate: String?
    let lastRestocked: String?
    let reorderLevel: Int

    /// Alerting enabled for this item.
    var hasReorderLevel: Bool { reorderLevel > 0 }
    /// Matches the backend rule: level > 0 and quantity at/below it.
    var isLowStock: Bool { reorderLevel > 0 && quantity <= reorderLevel }
    var isOutOfStock: Bool { quantity <= 0 }
    var totalValue: Int { quantity * costPrice }

    init(id: String, name: String, quantity: Int, costPrice: Int, unit: String = "piece",
         purchaseDate: String? = nil, lastRestocked: String? = nil, reorderLevel: Int = 0) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.costPrice = costPrice
        self.unit = unit
        self.purchaseDate = purchaseDate
        self.lastRestocked = lastRestocked
        self.reorderLevel = reorderLevel
    }
    convenience init(json: JSON) {
        self.init(
            id: json.string("id"),
            name: json.string("name"),
            quantity: json.int("quantity"),
            costPrice: json.int("cost_price"),
            unit: json.optString("unit") ?? "piece",
            purchaseDate: json.optString("purchase_date"),
            lastRestocked: json.optString("last_restocked"),
            reorderLevel: json.int("reorder_level")
        )
    }
    func toJson() -> JSON {
        [
            "id": id, "name": name, "quantity": quantity, "cost_price": costPrice,
            "unit": unit, "purchase_date": purchaseDate as Any,
            "last_restocked": lastRestocked as Any, "reorder_level": reorderLevel,
        ]
    }
}

/// One entry of `GET /admin/inventory/alerts`.
struct LowStockAlert: Identifiable {
    var id: String { alertId ?? item }
    let alertId: String?
    let item: String
    let qty: Int
    let reorderLevel: Int
    let unit: String
    let outOfStock: Bool

    init(item: String, qty: Int, reorderLevel: Int, alertId: String? = nil,
         unit: String = "piece", outOfStock: Bool = false) {
        self.alertId = alertId
        self.item = item
        self.qty = qty
        self.reorderLevel = reorderLevel
        self.unit = unit
        self.outOfStock = outOfStock
    }
    init(json: JSON) {
        self.alertId = json.optString("id")
        self.item = json.string("item")
        self.qty = json.int("qty")
        self.reorderLevel = json.int("reorder_level")
        self.unit = json.optString("unit") ?? "piece"
        self.outOfStock = json.bool("out_of_stock")
    }
}
