import Foundation

/// Base64 and hex, over the UTF-8 bytes of the text. Encoding cannot fail;
/// decoding can, and throws `FormatError` so the buffer is left untouched and
/// the message lands in the banner.
nonisolated enum Bytes {
    /// Standard padded alphabet, never line-wrapped.
    static func base64Encoded(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    /// Deliberately permissive where encoding is strict: whitespace and line
    /// breaks are ignored, the URL-safe `-` and `_` alphabet is accepted, and
    /// missing padding is filled in. Real-world base64 arrives wrapped, and a
    /// JWT segment is base64url with the padding stripped.
    static func base64Decoded(_ text: String) throws -> String {
        var body = text.filter { !$0.isWhitespace }
        guard !body.isEmpty else { return "" }
        body = String(body.map { (character: Character) -> Character in
            if character == "-" { return "+" }
            if character == "_" { return "/" }
            return character
        })
        while body.hasSuffix("=") { body.removeLast() }
        guard body.allSatisfy(base64Alphabet.contains) else {
            throw FormatError(message: "Not valid Base64: unexpected character.")
        }
        guard body.count % 4 != 1 else {
            throw FormatError(message: "Not valid Base64: the input is truncated.")
        }
        let padding = String(repeating: "=", count: (4 - body.count % 4) % 4)
        guard let data = Data(base64Encoded: body + padding) else {
            throw FormatError(message: "Not valid Base64: could not decode.")
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw FormatError(message: "Not valid Base64: the bytes are binary, not text.")
        }
        return decoded
    }

    /// Lowercase, no separators.
    static func hexEncoded(_ text: String) -> String {
        Data(text.utf8).map { String(format: "%02x", $0) }.joined()
    }

    /// Accepts uppercase, whitespace between bytes, and a leading `0x`.
    static func hexDecoded(_ text: String) throws -> String {
        var digits = text.filter { !$0.isWhitespace }
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") { digits.removeFirst(2) }
        guard !digits.isEmpty else { return "" }
        guard digits.count % 2 == 0 else {
            throw FormatError(message: "Not valid hex: an odd number of digits.")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else {
                throw FormatError(message: "Not valid hex: unexpected character.")
            }
            bytes.append(byte)
            index = next
        }
        guard let decoded = String(data: Data(bytes), encoding: .utf8) else {
            throw FormatError(message: "Not valid hex: the bytes are binary, not text.")
        }
        return decoded
    }

    private static let base64Alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
}
