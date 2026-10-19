import Foundation

/// A cafe table: occupancy plus optional floor-map layout.
/// Layout fields are percent-of-canvas (0–100), all optional.
final class CafeTable: Identifiable {
    var id: String { number }
    let number: String
    let status: String        // "empty" | "occupied"
    let orderId: String?
    let takenBy: String?
    let zone: String
    let x: Int?
    let y: Int?
    let w: Int?
    let h: Int?
    let shape: String         // "rect" | "round"

    var isOccupied: Bool { status == "occupied" }
    var isRound: Bool { shape == "round" }
    /// True when the owner has saved explicit floor coordinates.
    var hasLayout: Bool { x != nil && y != nil && w != nil && h != nil }

    init(
        number: String, status: String, orderId: String?, takenBy: String?,
        zone: String = "main", x: Int? = nil, y: Int? = nil,
        w: Int? = nil, h: Int? = nil, shape: String = "rect"
    ) {
        self.number = number
        self.status = status
        self.orderId = orderId
        self.takenBy = takenBy
        self.zone = zone
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.shape = shape
    }
    convenience init(json: JSON) {
        self.init(
            number: json["number"].map { "\($0)" } ?? "",
            status: json.string("status", "empty"),
            orderId: json.optString("order_id"),
            takenBy: json.optString("taken_by"),
            zone: json.optString("zone") ?? "main",
            x: json.optInt("x"),
            y: json.optInt("y"),
            w: json.optInt("w"),
            h: json.optInt("h"),
            shape: json.optString("shape") ?? "rect"
        )
    }
}

/// Percent-of-canvas rectangle used to position a table on the floor map.
struct TableRect: Equatable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

/// Grid fallback for tables without saved coordinates.
func fallbackRect(_ index: Int, total: Int = 1, cols: Int = 4) -> TableRect {
    let n = max(total, 1)
    let useCols = min(n, cols)
    let rows = (n + useCols - 1) / useCols
    let gap = 3
    let col = index % useCols
    let row = index / useCols
    let w = (100 - gap * (useCols + 1)) / useCols
    let h = (100 - gap * (rows + 1)) / max(rows, 1)
    return TableRect(x: gap + col * (w + gap), y: gap + row * (h + gap), w: w, h: h)
}
