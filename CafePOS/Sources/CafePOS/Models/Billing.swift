import Foundation

/// A day's worth of collected orders as returned by /admin/billing.
final class BillingDay: Identifiable {
    var id: String { date }
    let date: String
    let orders: [CafeOrder]
    let orderCount: Int
    let total: Int
    let paid: Int
    let unpaid: Int
    let byPayment: [String: Int]

    init(date: String, orders: [CafeOrder], orderCount: Int, total: Int,
         paid: Int, unpaid: Int, byPayment: [String: Int]) {
        self.date = date
        self.orders = orders
        self.orderCount = orderCount
        self.total = total
        self.paid = paid
        self.unpaid = unpaid
        self.byPayment = byPayment
    }
    convenience init(json: JSON) {
        self.init(
            date: json.string("date"),
            orders: json.jsonArray("orders").map(CafeOrder.init(json:)),
            orderCount: json.int("order_count"),
            total: json.int("total"),
            paid: json.int("paid"),
            unpaid: json.int("unpaid"),
            byPayment: json.intMap("by_payment")
        )
    }
}

/// Aggregated billing view for the owner: collected orders grouped by day.
final class BillingSummary {
    let days: [BillingDay]
    let orderCount: Int
    let total: Int
    let paid: Int
    let unpaid: Int

    init(days: [BillingDay], orderCount: Int, total: Int, paid: Int, unpaid: Int) {
        self.days = days
        self.orderCount = orderCount
        self.total = total
        self.paid = paid
        self.unpaid = unpaid
    }
    convenience init(json: JSON) {
        let summary = json.json("summary")
        self.init(
            days: json.jsonArray("days").map(BillingDay.init(json:)),
            orderCount: summary.int("order_count"),
            total: summary.int("total"),
            paid: summary.int("paid"),
            unpaid: summary.int("unpaid")
        )
    }
}
