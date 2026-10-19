import SwiftUI

@main
struct CafeApp: App {
    @StateObject private var services: ServiceHolder

    @MainActor
    init() {
        _services = StateObject(wrappedValue: ServiceHolder())
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environmentObject(services.auth)
                .environmentObject(services.tenant)
                .environmentObject(services.cart)
                .environmentObject(services)
                .environment(\.api, services.api)
                .tint(CafePalette.coffee)
                .task { await services.auth.load() }
        }
    }
}

/// Owns the long-lived services + state objects and exposes them to SwiftUI.
/// Created once at app launch so they survive rebuilds (like main.dart).
@MainActor
final class ServiceHolder: ObservableObject {
    let api: ApiServicing
    let auth: AuthState
    let tenant: TenantState
    let cart: CartState

    /// Flip to false + set the backend URL to run against the live Flask API.
    static let useMock = true

    @MainActor
    init() {
        let api: ApiServicing = Self.useMock ? MockApiClient() : LiveApiClient()
        self.api = api
        self.auth = AuthState(api: api)
        self.tenant = TenantState(api: api)
        self.cart = CartState()
    }
}

/// Environment key so any view can reach the ApiServicing without prop-drilling.
private struct ApiKey: EnvironmentKey {
    static let defaultValue: ApiServicing = MockApiClient()
}
extension EnvironmentValues {
    var api: ApiServicing {
        get { self[ApiKey.self] }
        set { self[ApiKey.self] = newValue }
    }
}
