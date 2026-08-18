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

    /// UTC and whole seconds. Local time was rejected as ambiguous for logs and
    /// untestable across machines. Values too large to be seconds are read as
    /// milliseconds: 1e11 seconds is the year 5138, so nothing real collides.
    private static func date(fromTimestamp text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.wholeMatch(of: #/[+-]?\d+(?:\.\d+)?/#) != nil,
              let value = Double(trimmed), value.isFinite else {
            throw FormatError(message: "Not a Unix timestamp: expected a number of seconds.")
        }
        let seconds = (abs(value) >= 1e11 ? value / 1000 : value).rounded(.towardZero)
        return formatter(with: [.withInternetDateTime])
            .string(from: Date(timeIntervalSince1970: seconds))
    }

    /// The whole selection is treated as one value. Rewriting every timestamp
    /// inside a log is a different, larger feature.
    private static func timestamp(fromDate text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attempts: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withFullDate],
        ]
        for options in attempts {
            if let date = formatter(with: options).date(from: trimmed) {
                return String(Int(date.timeIntervalSince1970.rounded(.towardZero)))
            }
        }
        throw FormatError(message: "Not an ISO 8601 date: expected something like 2023-11-14T22:13:20Z.")
    }

    /// Built per call rather than cached: `ISO8601DateFormatter` is a mutable
    /// reference type and not `Sendable`, and these run once per menu click.
    private static func formatter(with options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
