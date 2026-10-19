import SwiftUI

/// Extended cafe palette — mirrors `ui_kit.dart`'s CafePalette.
extension CafePalette {
    static let cream = Color(hex: 0xFFF6F4F1)
    static let mint = Color(hex: 0xFF5FAB86)
    static let berry = Color(hex: 0xFFB3546E)
    static let sunshine = Color(hex: 0xFFF2B251)
    static let sky = Color(hex: 0xFF5B8DEF)
    static let peach = Color(hex: 0xFFE8845C)
    static let mist = Color(hex: 0xFFE4E6EB)
    static let charcoal = Color(hex: 0xFF333333)
}

/// Named gradients used across cards/tiles.
enum CafeGradients {
    static let coffee = LinearGradient(colors: [Color(hex: 0xFF6F4E37), Color(hex: 0xFFA0785A)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let espresso = LinearGradient(colors: [Color(hex: 0xFF4E3626), Color(hex: 0xFF6F4E37)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sunrise = LinearGradient(colors: [Color(hex: 0xFFF2B251), Color(hex: 0xFFE8845C)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let peach = LinearGradient(colors: [Color(hex: 0xFFFFB88C), Color(hex: 0xFFE8845C)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mint = LinearGradient(colors: [Color(hex: 0xFF5FAB86), Color(hex: 0xFF8FD0AA)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let berry = LinearGradient(colors: [Color(hex: 0xFFB3546E), Color(hex: 0xFFD98A9E)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sky = LinearGradient(colors: [Color(hex: 0xFF5B8DEF), Color(hex: 0xFF8FB8F8)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)

    static let all: [LinearGradient] = [coffee, sunrise, peach, mint, berry, sky]

    /// Stable pick from a seed string so the same category/dish always gets
    /// the same gradient.
    static func forSeed(_ seed: String) -> LinearGradient {
        var hash: UInt64 = 5381
        for b in seed.utf8 { hash = hash &* 33 &+ UInt64(b) }
        return all[Int(hash % UInt64(all.count))]
    }
}

/// Emoji stand-ins for food/drink art — offline-safe "images".
func categoryEmoji(_ category: String) -> String {
    let c = category.lowercased().replacingOccurrences(of: "_", with: " ")
    if c.contains("coffee") || c.contains("espresso") || c.contains("latte") { return "☕" }
    if c.contains("tea") || c.contains("chai") { return "🍵" }
    if c.contains("cold") || c.contains("drink") || c.contains("juice") { return "🥤" }
    if c.contains("shake") || c.contains("smoothie") { return "🥛" }
    if c.contains("farsan") || c.contains("snack") || c.contains("namkeen") { return "🥟" }
    if c.contains("sandwich") || c.contains("toast") { return "🥪" }
    if c.contains("pizza") { return "🍕" }
    if c.contains("burger") { return "🍔" }
    if c.contains("fries") || c.contains("chaat") { return "🍟" }
    if c.contains("dessert") || c.contains("sweet") || c.contains("cake") { return "🍰" }
    if c.contains("ice") || c.contains("kulfi") { return "🍨" }
    if c.contains("main") || c.contains("meal") || c.contains("thali") { return "🍛" }
    if c.contains("bread") || c.contains("bun") || c.contains("bakery") { return "🥐" }
    return "🍽️"
}

/// Best-effort dish emoji by name keyword, falling back to category.
func dishEmoji(_ name: String, category: String = "") -> String {
    let n = name.lowercased()
    let keywords: [(String, String)] = [
        ("coffee", "☕"), ("espresso", "☕"), ("cappuccino", "☕"), ("latte", "☕"),
        ("mocha", "☕"), ("americano", "☕"), ("chai", "🍵"), ("tea", "🍵"),
        ("juice", "🧃"), ("cola", "🥤"), ("soda", "🥤"), ("shake", "🥛"),
        ("lassi", "🥛"), ("samosa", "🥟"), ("sandwich", "🥪"), ("grill", "🥪"),
        ("toast", "🥪"), ("pizza", "🍕"), ("burger", "🍔"), ("fries", "🍟"),
        ("pasta", "🍝"), ("noodles", "🍜"), ("dosa", "🥞"), ("idli", "🍚"),
        ("cake", "🍰"), ("pastry", "🍰"), ("brownie", "🍫"), ("ice cream", "🍨"),
        ("kulfi", "🍨"), ("thali", "🍛"), ("curry", "🍛"), ("paneer", "🧆"),
        ("rice", "🍚"), ("roti", "🫓"),
    ]
    for (k, v) in keywords where n.contains(k) { return v }
    return categoryEmoji(category)
}
