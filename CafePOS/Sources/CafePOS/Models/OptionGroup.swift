import Foundation

struct OptionChoice: Equatable, Identifiable {
    var id: String { label }
    let label: String
    let priceDelta: Int

    init(label: String, priceDelta: Int) {
        self.label = label
        self.priceDelta = priceDelta
    }
    init(json: JSON) {
        self.label = json.string("label")
        self.priceDelta = json.int("price_delta")
    }
}

struct OptionGroup: Equatable, Identifiable {
    var id: String { group }
    let group: String
    let isRequired: Bool
    let multi: Bool
    let choices: [OptionChoice]

    init(group: String, required: Bool, multi: Bool, choices: [OptionChoice]) {
        self.group = group
        self.isRequired = required
        self.multi = multi
        self.choices = choices
    }
    init(json: JSON) {
        self.group = json.string("group")
        self.isRequired = json.bool("required")
        self.multi = json.bool("multi")
        self.choices = json.jsonArray("choices").map(OptionChoice.init(json:))
    }
}

/// A single chosen option, sent back to the server as {group, label}.
struct SelectedOption: Equatable, Hashable {
    let group: String
    let label: String

    init(group: String, label: String) {
        self.group = group
        self.label = label
    }
    init(json: JSON) {
        self.group = json.string("group")
        self.label = json.string("label")
    }
    func toJson() -> JSON {
        ["group": group, "label": label]
    }
}
