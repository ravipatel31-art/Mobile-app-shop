import Foundation

/// Error thrown by every ApiClient call. Mirrors Dart's ApiException.
struct ApiException: Error, LocalizedError {
    let message: String
    let statusCode: Int?

    init(_ message: String, statusCode: Int? = nil) {
        self.message = message
        self.statusCode = statusCode
    }
    var errorDescription: String? { message }
}
