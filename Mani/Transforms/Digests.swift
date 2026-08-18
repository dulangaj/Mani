import CryptoKit
import Foundation

/// Cryptographic digests of the text's UTF-8 bytes — including any trailing
/// newline, which is why the result matches `shasum file` rather than
/// `echo -n | shasum`. Named `Digests` rather than `Digest` so it cannot be
/// confused with CryptoKit's protocol of that name.
nonisolated enum Digests {
    nonisolated enum Algorithm: String, CaseIterable, Sendable {
        case md5 = "MD5"
        case sha1 = "SHA-1"
        case sha256 = "SHA-256"
        case sha512 = "SHA-512"
    }

    /// Empty in, empty out — Mani's invariant across every non-failing action.
    /// The true digest of the empty string is never what you wanted from an
    /// empty buffer, and the bottom bar is disabled there anyway.
    static func hex(_ text: String, _ algorithm: Algorithm) -> String {
        guard !text.isEmpty else { return "" }
        let data = Data(text.utf8)
        let bytes: [UInt8]
        switch algorithm {
        case .md5: bytes = Array(Insecure.MD5.hash(data: data))
        case .sha1: bytes = Array(Insecure.SHA1.hash(data: data))
        case .sha256: bytes = Array(SHA256.hash(data: data))
        case .sha512: bytes = Array(SHA512.hash(data: data))
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
