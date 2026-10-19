import Foundation

/// One AI suggestion from POST /recommend.
struct Suggestion: Identifiable {
    var id: String { item.id }
    let item: MenuItem
    let reason: String
    let unitPrice: Int           // minor units, base + default option deltas
    let defaultOptions: [SelectedOption]
    let safeToAutopick: Bool

    init(item: MenuItem, reason: String, unitPrice: Int,
         defaultOptions: [SelectedOption], safeToAutopick: Bool) {
        self.item = item
        self.reason = reason
        self.unitPrice = unitPrice
        self.defaultOptions = defaultOptions
        self.safeToAutopick = safeToAutopick
    }
    init(json: JSON) {
        self.item = MenuItem(json: json.json("item"))
        self.reason = json.string("reason")
        self.unitPrice = json.int("unit_price")
        self.defaultOptions = json.jsonArray("default_options").map(SelectedOption.init(json:))
        self.safeToAutopick = json.bool("safe_to_autopick")
    }
}
