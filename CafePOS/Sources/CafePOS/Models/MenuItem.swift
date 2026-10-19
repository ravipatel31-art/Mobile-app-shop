import Foundation

struct MenuItem: Equatable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let basePrice: Int      // minor units
    let imageUrl: String?
    let available: Bool
    let options: [OptionGroup]
    let gstRate: Int        // 0/5/12/18
    let hsnCode: String

    init(
        id: String, name: String, description: String, category: String,
        basePrice: Int, imageUrl: String?, available: Bool, options: [OptionGroup],
        gstRate: Int = 5, hsnCode: String = "9963"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.basePrice = basePrice
        self.imageUrl = imageUrl
        self.available = available
        self.options = options
        self.gstRate = gstRate
        self.hsnCode = hsnCode
    }
    init(json: JSON) {
        self.id = json.string("id")
        self.name = json.string("name")
        self.description = json.string("description")
        self.category = json.string("category", "other")
        self.basePrice = json.int("base_price")
        self.imageUrl = json.optString("image_url")
        self.available = json.bool("available", true)
        self.options = json.jsonArray("options").map(OptionGroup.init(json:))
        self.gstRate = json.int("gst_rate", 5)
        self.hsnCode = json.string("hsn_code", "9963")
    }
}
