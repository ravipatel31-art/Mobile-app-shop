import Foundation
import SwiftUI

/// Holds the logged-in session (owner/staff/kitchen/cafe_ca). RootGate uses
/// [role] to pick the right experience; nil token = logged out. [tenant] names
/// the cafe the session belongs to on the multi-tenant backend.
@MainActor
final class AuthState: ObservableObject {
    private let api: ApiServicing
    private let storageKey = "cafe_session"

    @Published var token: String?
    @Published var role: String?        // "owner" | "staff" | "kitchen" | "cafe_ca"
    @Published var username: String?
    @Published var name: String?
    @Published var tenant: String?
    @Published var loading = true

    var isLoggedIn: Bool { token != nil }
    var isOwner: Bool { role == "owner" }
    var isStaff: Bool { role == "staff" }
    var isKitchen: Bool { role == "kitchen" }

    init(api: ApiServicing) {
        self.api = api
    }

    /// Restores any persisted session. Best-effort; never throws.
    func load() async {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let obj = try? JSONSerialization.jsonObject(with: data) as? JSON {
            token = obj.optString("token")
            role = obj.optString("role")
            username = obj.optString("username")
            name = obj.optString("name")
            tenant = obj.optString("tenant")
            api.token = token
        }
        loading = false
    }

    func login(_ user: String, _ password: String, tenant: String?) async throws {
        let result = try await api.login(user, password, tenant: tenant)
        token = result.string("token")
        role = result.optString("role")
        username = result.optString("username")
        name = result.optString("name")
        self.tenant = result.optString("tenant")
        api.token = token
        persist()
    }

    func register(_ user: String, _ password: String, _ name: String) async throws {
        try await api.register(user, password, name)
    }

    func logout() async {
        token = nil
        role = nil
        username = nil
        name = nil
        tenant = nil
        api.token = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func persist() {
        let obj: JSON = [
            "token": token as Any, "role": role as Any, "username": username as Any,
            "name": name as Any, "tenant": tenant as Any,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
