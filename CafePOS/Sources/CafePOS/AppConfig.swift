import Foundation

/// Port of `config.dart` — base URL, currency and payment/WhatsApp settings.
enum AppConfig {
    /// Base URL of the Flask backend. Override at build time via the
    /// `API_BASE_URL` build flag; defaults to the production tunnel.
    static let baseUrl: String = {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        // On the iOS simulator, localhost reaches the host machine directly.
        return productionBaseUrl
    }()

    /// Production API base URL (Cloudflare tunnel).
    static let productionBaseUrl = "https://mobileapp.unonomercysound.online"

    /// Currency symbol used across the UI. Amounts are integers in minor units.
    static let currencySymbol = "₹"
    static let currencyCode = "INR"
    static let countryCode = "IN"

    // ---- UPI Payments ----
    static let upiId = "ravi.chudgar-1@okicici"
    static let merchantName = "Cafe POS"

    // ---- WhatsApp ----
    static let vendorPhone = "919998814647"
}
