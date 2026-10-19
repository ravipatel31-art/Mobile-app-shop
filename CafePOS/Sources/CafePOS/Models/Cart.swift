import Foundation

/// One configured line in the cart. Price is previewed client-side; the server
/// is authoritative at checkout.
final class CartLine: Identifiable {
    let id = UUID()
    let item: MenuItem
    let selectedOptions: [SelectedOption]
    var qty: Int

    init(item: MenuItem, selectedOptions: [SelectedOption], qty: Int = 1) {
        self.item = item
        self.selectedOptions = selectedOptions
        self.qty = qty
    }

    var unitPrice: Int {
        var price = item.basePrice
        for sel in selectedOptions {
            let group = item.options.first(where: { $0.group == sel.group })
                ?? OptionGroup(group: "", required: false, multi: false, choices: [])
            for choice in group.choices where choice.label == sel.label {
                price += choice.priceDelta
            }
        }
        return price
    }

    var lineTotal: Int { unitPrice * qty }

    /// Short human summary of chosen options, e.g. "Large · Oat".
    var optionsSummary: String { selectedOptions.map(\.label).joined(separator: " · ") }

    func toOrderItemJson() -> JSON {
        [
            "item_id": item.id,
            "qty": qty,
            "selected_options": selectedOptions.map { $0.toJson() },
        ]
    }
}
