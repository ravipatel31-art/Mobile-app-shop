import SwiftUI

/// Sign-in screen — port of `login_screen.dart`. Gradient hero + credentials
/// card + collapsible demo-credential hint.
struct LoginScreen: View {
    @EnvironmentObject private var auth: AuthState
    @State private var user = ""
    @State private var pass = ""
    @State private var tenant = ""
    @State private var busy = false
    @State private var obscure = true
    @State private var showDemo = false
    @State private var error: String?

    private let roles = ["Owner", "Staff", "Kitchen", "CA"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                signInCard
                demoHint
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0xFFF1E8DE), CafePalette.cream],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(.white).font(.system(size: 24)))
                    .overlay(Circle().stroke(.white.opacity(0.35)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Café POS")
                        .font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
                    Text("Billing · KOT · QR orders · GST")
                        .font(.caption).foregroundStyle(.white.opacity(0.88))
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            FlowWrap(roles) { role in
                Text(role)
                    .font(.system(size: 12.5, weight: .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.15)))
                    .overlay(Capsule().stroke(.white.opacity(0.3)))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24).fill(CafeGradients.coffee)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        )
    }

    private var signInCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "person").foregroundStyle(.secondary)
                TextField("Username", text: $user)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .inputRow()

            HStack {
                Image(systemName: "lock").foregroundStyle(.secondary)
                if obscure {
                    SecureField("Password", text: $pass)
                } else {
                    TextField("Password", text: $pass)
                }
                Button { obscure.toggle() } label: {
                    Image(systemName: obscure ? "eye" : "eye.slash")
                        .foregroundStyle(.secondary)
                }
            }
            .inputRow()

            HStack {
                Image(systemName: "storefront").foregroundStyle(.secondary)
                TextField("Cafe code", text: $tenant)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await login() } }
            }
            .inputRow()

            if let error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    Text(error).foregroundStyle(.red).font(.caption)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
            }

            Button(action: { Task { await login() } }) {
                HStack {
                    if busy { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.forward") }
                    Text(busy ? "Signing in…" : "Sign in").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(CafePalette.coffee, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(busy)

            NavigationLink("New staff? Request an account") { RegisterScreen() }
                .font(.caption)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.05))))
    }

    private var demoHint: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { showDemo.toggle() } } label: {
                HStack {
                    IconChip(icon: "key", gradient: CafeGradients.sunrise, size: 34, iconSize: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo credentials").font(.system(size: 14, weight: .bold))
                        Text(showDemo ? "Tap a row to fill the form" : "Try the app in a few taps")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: showDemo ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            if showDemo {
                VStack(spacing: 0) {
                    demoRow("owner", "cafe123", "Owner")
                    demoRow("priya", "staff123", "Staff")
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.9))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(CafePalette.latte)))
    }

    private func demoRow(_ u: String, _ p: String, _ role: String) -> some View {
        Button {
            user = u; pass = p; error = nil
        } label: {
            HStack {
                Text(u).font(.system(size: 14, weight: .bold))
                Spacer()
                Text(p).font(.caption).fontWeight(.semibold).foregroundStyle(CafePalette.coffee)
                Text(role).font(.caption2).foregroundStyle(Color(hex: 0xFF8A6A52))
                Image(systemName: "arrow.forward").font(.caption2).foregroundStyle(CafePalette.caramel)
            }
            .padding(.horizontal, 6).padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func login() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await auth.login(user.trimmingCharacters(in: .whitespaces), pass,
                                 tenant: tenant.trimmingCharacters(in: .whitespaces))
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }
}

private extension View {
    func inputRow() -> some View {
        self.padding(.vertical, 14).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFFFAF9F7)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.05)))
    }
}
