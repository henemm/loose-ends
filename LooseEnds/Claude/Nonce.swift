import CryptoKit
import Foundation
import Security

enum NonceError: Error, Equatable {
    case randomUnavailable(Int32)
}

/// The nonce of a sign-in with Apple (#615 S4b-1): Apple gets `hashed`, the service gets `raw` and compares
/// SHA-256 of its UTF-8 bytes, lowercase hex, with the identity token's claim (`server/src/apple.ts`).
struct Nonce: Sendable, Equatable {
    let raw: String

    /// 32 random bytes, base64url without padding (43 characters). A failing random source throws, never a weaker value.
    init() throws {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw NonceError.randomUnavailable(status) }
        raw = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init(raw: String) {
        self.raw = raw
    }

    var hashed: String { Self.hash(raw) }

    static func hash(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
