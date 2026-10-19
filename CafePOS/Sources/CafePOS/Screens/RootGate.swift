import SwiftUI

/// Login-first routing, mirroring `RootGate` in main.dart:
/// logged out -> login; owner/staff/kitchen/cafe_ca -> their shell.
struct RootGate: View {
    @EnvironmentObject private var auth: AuthState

    var body: some View {
        Group {
            if auth.loading {
                splash
            } else if !auth.isLoggedIn {
                LoginScreen()
            } else if auth.isOwner {
                OwnerShell()
            } else if auth.role == "cafe_ca" {
                CaShell()
            } else if auth.isKitchen {
                KitchenShell()
            } else {
                StaffShell()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isLoggedIn)
    }

    private var splash: some View {
        ZStack {
            CafePalette.background.ignoresSafeArea()
            ProgressView().tint(CafePalette.coffee)
        }
    }
}
