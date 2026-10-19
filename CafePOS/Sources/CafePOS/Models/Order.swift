import Foundation

struct OrderLine: Equatable, Identifiable {
    var id: String { "\(name)-\(unitPrice)-\(qty)" }
    let name: String
    let category: String
    let qty: Int
    let unitPrice: Int
    let lineTotal: Int
    let options: [String]
    let taxableValue: Int
    let cgst: Int
    let sgst: Int
    let gstRate: Int?
    let hsnCode: String?

    var taxTotal: Int { cgst + sgst }

    init(
        name: String, category: String, qty: Int, unitPrice: Int, lineTotal: Int,
        options: [String], taxableValue: Int = 0, cgst: Int = 0, sgst: Int = 0,
        gstRate: Int? = nil, hsnCode: String? = nil
    ) {
        self.name = name
        self.category = category
        self.qty = qty
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
        self.options = options
        self.taxableValue = taxableValue
        self.cgst = cgst
        self.sgst = sgst
        self.gstRate = gstRate
        self.hsnCode = hsnCode
    }
    init(json: JSON) {
        self.name = json.string("name")
        self.category = json.string("category", "other")
        self.qty = json.int("qty", 1)
        self.unitPrice = json.int("unit_price")
        self.lineTotal = json.int("line_total")
        self.options = json.jsonArray("selected_options").map { $0.string("label") }
        self.taxableValue = json.int("taxable_value")
        self.cgst = json.int("cgst")
        self.sgst = json.int("sgst")
        self.gstRate = json.optInt("gst_rate")
        self.hsnCode = json.optString("hsn_code")
    }
}

final class CafeOrder: Identifiable {
    let id: String
    let items: [OrderLine]
    let total: Int
    let subTotal: Int
    let taxTotal: Int
    let customerName: String
    let customerPhone: String?
    let pickupType: String
    let tableNumber: String?
    var status: String
    let createdAt: String
    let notes: String
    let takenBy: String?
    let paymentMethod: String
    let paymentStatus: String
    let paidAmount: Int
    let paymentToken: String?
    let payments: [JSON]

    /// What's still owed after a reopen (total minus amount already paid).
    var remaining: Int { total - paidAmount }

    static let flow = ["received", "preparing", "ready", "collected"]

    init(
        id: String, items: [OrderLine], total: Int, customerName: String,
        customerPhone: String?, pickupType: String, tableNumber: String?,
        status: String, createdAt: String, notes: String, takenBy: String?,
        paymentMethod: String, paymentStatus: String, paidAmount: Int = 0,
        paymentToken: String? = nil, subTotal: Int = 0, taxTotal: Int = 0,
        payments: [JSON] = []
    ) {
        self.id = id
        self.items = items
        self.total = total
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.pickupType = pickupType
        self.tableNumber = tableNumber
        self.status = status
        self.createdAt = createdAt
        self.notes = notes
        self.takenBy = takenBy
        self.paymentMethod = paymentMethod
        self.paymentStatus = paymentStatus
        self.paidAmount = paidAmount
        self.paymentToken = paymentToken
        self.subTotal = subTotal
        self.taxTotal = taxTotal
        self.payments = payments
    }
    convenience init(json: JSON) {
        let total = json.int("total")
        self.init(
            id: json.string("id"),
            items: json.jsonArray("items").map(OrderLine.init(json:)),
            total: total,
            customerName: json.json("customer").string("name", "Guest"),
            customerPhone: json.json("customer").optString("phone"),
            pickupType: json.string("pickup_type", "counter"),
            tableNumber: json.optString("table_number"),
            status: json.string("status", "received"),
            createdAt: json.string("created_at"),
            notes: json.string("notes"),
            takenBy: json.optString("taken_by"),
            paymentMethod: json.string("payment_method", "cash"),
            paymentStatus: json.string("payment_status", "unpaid"),
            paidAmount: json.int("paid_amount"),
            paymentToken: json.optString("payment_token"),
            subTotal: json.int("sub_total", total),
            taxTotal: json.int("tax_total"),
            payments: json.jsonArray("payments")
        )
    }
}
