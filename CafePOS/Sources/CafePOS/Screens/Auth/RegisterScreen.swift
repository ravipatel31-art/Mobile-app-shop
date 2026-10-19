import SwiftUI

/// Request-a-staff-account screen — port of `register_screen.dart`.
struct RegisterScreen: View {
    @EnvironmentObject private var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var user = ""
    @State private var pass = ""
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        Form {
            Section("Request an account") {
                TextField("Username", text: $user).textInputAutocapitalization(.never)
                TextField("Full name", text: $name)
                SecureField("Password", text: $pass)
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
            if done {
                Section {
                    Label("Request sent — an owner must approve it",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            Section {
                Button {
                    Task { await register() }
                } label: {
                    if busy { ProgressView() } else { Text("Submit request") }
                }
                .disabled(busy || user.isEmpty || pass.isEmpty || name.isEmpty)
            }
        }
        .navigationTitle("New staff account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func register() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await auth.register(user, pass, name)
            done = true
        } catch {
            self.error = "\(error.localizedDescription)"
        }
    }
}
