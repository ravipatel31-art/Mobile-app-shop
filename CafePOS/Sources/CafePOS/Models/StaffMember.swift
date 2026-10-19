import Foundation

struct StaffMember: Identifiable {
    var id: String { username }
    let username: String
    let name: String
    let role: String      // "owner" | "staff"
    let status: String    // "pending" | "approved"
    let lastLogin: String?

    var isPending: Bool { status == "pending" }
    var isOwner: Bool { role == "owner" }

    init(username: String, name: String, role: String, status: String, lastLogin: String?) {
        self.username = username
        self.name = name
        self.role = role
        self.status = status
        self.lastLogin = lastLogin
    }
    init(json: JSON) {
        let username = json.string("username")
        self.username = username
        self.name = json.optString("name") ?? username
        self.role = json.string("role", "staff")
        self.status = json.string("status", "pending")
        self.lastLogin = json.optString("last_login")
    }
}
