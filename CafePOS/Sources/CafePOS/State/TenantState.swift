import Foundation
import SwiftUI

/// Per-cafe branding for the tenant currently in scope, backed by
/// `GET /public/<slug>/config`. All best-effort: failures leave branding empty.
@MainActor
final class TenantState: ObservableObject {
    /// Slug the backend falls back to when no cafe code is given.
    static let defaultSlug = "main"

    private let api: ApiServicing

    @Published var slug = ""
    @Published var displayName = ""
    @Published var kind = ""
    @Published var billFooter = ""

    var hasBranding: Bool { !displayName.isEmpty }

    init(api: ApiServicing) {
        self.api = api
    }

    /// Loads branding for [slug]; nil/blank means defaultSlug.
    func loadFor(_ slug: String?) async {
        let target = (slug ?? "").trimmingCharacters(in: .whitespaces)
        let effective = target.isEmpty ? Self.defaultSlug : target
        if effective == self.slug && hasBranding { return }
        if !self.slug.isEmpty && self.slug != effective {
            self.slug = effective
            displayName = ""
            kind = ""
            billFooter = ""
        }
        self.slug = effective
        if let config = try? await api.fetchTenantConfig(effective) {
            displayName = config.string("display_name")
            kind = config.string("kind")
            billFooter = config.string("bill_footer")
        }
    }
}
