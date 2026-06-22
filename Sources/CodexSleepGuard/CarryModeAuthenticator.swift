import Foundation
import LocalAuthentication

protocol CarryModeAuthenticating {
    func authenticateForCarryMode() async throws
}

final class LocalCarryModeAuthenticator: CarryModeAuthenticating {
    func authenticateForCarryMode() async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? CarryModeAuthenticationError.unavailable
        }

        let reason = "Carry Mode keeps this Mac awake while the lid is closed."
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? CarryModeAuthenticationError.cancelled)
                }
            }
        }
    }
}

private enum CarryModeAuthenticationError: LocalizedError {
    case unavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Password or Touch ID authentication is not available."
        case .cancelled:
            return "Carry Mode authentication was cancelled."
        }
    }
}
