import Foundation

struct TopItem: Identifiable {
    var id: String { name }
    let name: String
    let qty: Int
    let revenue: Int

    init(name: String, qty: Int, revenue: Int) {
        self.name = name
        self.qty = qty
        self.revenue = revenue
    }
    init(json: JSON) {
        self.name = json.string("name")
        self.qty = json.int("qty")
        self.revenue = json.int("revenue")
    }
}

final class SalesSummary {
    let date: String
    let orderCount: Int
    let grossSales: Int
    let byCategory: [String: Int]
    let byPayment: [String: Int]
    let topItems: [TopItem]

    init(date: String, orderCount: Int, grossSales: Int, byCategory: [String: Int],
         byPayment: [String: Int], topItems: [TopItem]) {
        self.date = date
        self.orderCount = orderCount
        self.grossSales = grossSales
        self.byCategory = byCategory
        self.byPayment = byPayment
        self.topItems = topItems
    }
    convenience init(json: JSON) {
        self.init(
            date: json.string("date"),
            orderCount: json.int("order_count"),
            grossSales: json.int("gross_sales"),
            byCategory: json.intMap("by_category"),
            byPayment: json.intMap("by_payment"),
            topItems: json.jsonArray("top_items").map(TopItem.init(json:))
        )
    }
}
