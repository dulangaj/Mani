import Foundation

/// The failing half of the operation vocabulary. `Transform` is total by
/// contract, which is worth keeping, so operations that can legitimately reject
/// their input live here instead and throw `FormatError` exactly like
/// `Formatter` does. The UI cannot tell the two apart.
nonisolated enum Conversion: CaseIterable, Identifiable, Sendable {
    case base64Decode
    case hexDecode
    case jwtDecode
    case timestampToDate
    case dateToTimestamp

    var id: Self { self }

    var label: String {
        switch self {
        case .base64Decode: "Base64 Decode"
        case .hexDecode: "Decode Hex Bytes"
        case .jwtDecode: "Decode JWT"
        case .timestampToDate: "Unix Timestamp → Date"
        case .dateToTimestamp: "Date → Unix Timestamp"
        }
    }

    var help: String {
        switch self {
        case .base64Decode: "Decode Base64, ignoring line breaks and accepting the URL-safe alphabet"
        case .hexDecode: "Decode a run of hex byte pairs back into text"
        case .jwtDecode: "Show a JSON Web Token's header and payload as JSON — the signature is not verified"
        case .timestampToDate: "Convert Unix seconds, or milliseconds, to an ISO 8601 date in UTC"
        case .dateToTimestamp: "Convert an ISO 8601 date to Unix seconds"
        }
    }

    func apply(to text: String) throws -> String {
        switch self {
        case .base64Decode: return try Bytes.base64Decoded(text)
        case .hexDecode: return try Bytes.hexDecoded(text)
        case .jwtDecode: return try Self.jwt(text)
        case .timestampToDate: return try Self.date(fromTimestamp: text)
        case .dateToTimestamp: return try Self.timestamp(fromDate: text)
        }
    }

    // MARK: - JSON Web Tokens

    /// Emits one JSON object, `{"header": …, "payload": …}`, pretty-printed
    /// through the existing formatter — so the result is itself valid JSON that
    /// Mani's other operations can chew on. Running the two raw segments
    /// through `Formatter.json` also validates both in a single pass.
    private static func jwt(_ text: String) throws -> String {
        let segments = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw FormatError(message: "Not a JSON Web Token: expected three dot-separated segments.")
        }
        let header = try segment(segments[0], named: "header")
        let payload = try segment(segments[1], named: "payload")
        do {
            return try Formatter.json(#"{"header":\#(header),"payload":\#(payload)}"#)
        } catch {
            throw FormatError(message: "Not a JSON Web Token: the header or payload is not JSON.")
        }
    }

    private static func segment(_ segment: Substring, named name: String) throws -> String {
        do {
            return try Bytes.base64Decoded(String(segment))
        } catch {
            throw FormatError(message: "Not a JSON Web Token: the \(name) is not base64url.")
        }
    }

    // MARK: - Timestamps

    /// UTC. Local time was rejected as ambiguous for logs and untestable across
    /// machines. The unit is inferred by magnitude, each rung being a thousand
    /// years past anything real: 1e11 seconds is the year 5138, so a value that
    /// large is milliseconds, and so on up. Pick the explicit command in the
    /// Timestamp submenu when you know the unit and want it obeyed.
    private static func date(fromTimestamp text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Timestamps.wholeTicks(trimmed) else {
            throw FormatError(message: "Not a Unix timestamp: expected a number of seconds.")
        }
        return try Timestamps.date(from: trimmed, unit: unit(for: value))
    }

    private static func unit(for value: Int64) -> TimestampUnit {
        switch value.magnitude {
        case ..<100_000_000_000: .seconds
        case ..<100_000_000_000_000: .milliseconds
        case ..<100_000_000_000_000_000: .microseconds
        default: .nanoseconds
        }
    }

    private static func timestamp(fromDate text: String) throws -> String {
        try Timestamps.timestamp(from: text, unit: .seconds)
    }
}
