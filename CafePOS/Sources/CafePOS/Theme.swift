import SwiftUI

/// Port of `buildAppTheme()` + the cafe color palette from the Flutter app.
enum CafePalette {
    static let coffee = Color(hex: 0xFF6F4E37)     // seed
    static let espresso = Color(hex: 0xFF4E3626)
    static let caramel = Color(hex: 0xFFB07D4F)
    static let latte = Color(hex: 0xFFEDE4DA)
    static let background = Color(hex: 0xFFF6F4F1)
    static let surface = Color.white
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Money helper: amounts are integers in minor units (paise).
enum Money {
    /// Formats minor units as a rupee string, e.g. 18000 -> "₹180.00".
    static func format(_ minor: Int, decimals: Int = 2) -> String {
        let major = Double(minor) / 100
        return AppConfig.currencySymbol + String(format: "%.\(decimals)f", major)
    }
    /// Whole-unit format, e.g. 18000 -> "₹180".
    static func whole(_ minor: Int) -> String { format(minor, decimals: 0) }
}

/// Date label used in shell subtitles, e.g. "Mon, 13 Oct".
func shellDateLabel(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE, d MMM"
    return f.string(from: date)
}
