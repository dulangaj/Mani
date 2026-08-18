import Foundation

/// Unix time in a stated unit, both directions.
///
/// The unit is named by the command you pick, so nothing is guessed. The one
/// guessing entry point is `Conversion.timestampToDate`, which is still there
/// for the everyday case where you paste a number and do not want to think.
nonisolated enum TimestampUnit: String, CaseIterable, Sendable {
    case seconds = "Seconds"
    case milliseconds = "Milliseconds"
    case microseconds = "Microseconds"
    case nanoseconds = "Nanoseconds"

    /// How many of this unit make a second.
    var perSecond: Int64 {
        switch self {
        case .seconds: 1
        case .milliseconds: 1_000
        case .microseconds: 1_000_000
        case .nanoseconds: 1_000_000_000
        }
    }
}

nonisolated enum Timestamps {
    /// Splitting the count into whole seconds and a remainder keeps the
    /// arithmetic in `Int64`: a nanosecond timestamp needs 19 significant
    /// digits and `Double` carries about 15, so dividing first would round the
    /// value before it was ever a date.
    static func date(from text: String, unit: TimestampUnit) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ticks = wholeTicks(trimmed) else {
            throw FormatError(message: "Not a Unix timestamp: expected a number of \(unit.rawValue.lowercased()).")
        }
        let whole = ticks / unit.perSecond
        let remainder = ticks % unit.perSecond
        let interval = Double(whole) + Double(remainder) / Double(unit.perSecond)
        return string(from: Date(timeIntervalSince1970: interval), fractional: remainder != 0)
    }

    /// Digits only, so `0x10` and `1e5` stay rejected the way they always were,
    /// rather than being quietly accepted by `Double`'s hex and exponent
    /// syntax. A fractional part truncates: sub-unit precision has nowhere to
    /// go once the value is already counted in this unit.
    static func wholeTicks(_ text: String) -> Int64? {
        guard text.wholeMatch(of: #/[+-]?\d+(?:\.\d+)?/#) != nil else { return nil }
        if let exact = Int64(text) { return exact }
        guard let value = Double(text)?.rounded(.towardZero), value.isFinite,
              value.magnitude < Double(Int64.max) else { return nil }
        return Int64(value)
    }

    /// The whole selection is treated as one value. Rewriting every timestamp
    /// inside a log is a different, larger feature.
    static func timestamp(from text: String, unit: TimestampUnit) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attempts: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withFullDate],
        ]
        for options in attempts {
            guard let date = formatter(with: options).date(from: trimmed) else { continue }
            let ticks = (date.timeIntervalSince1970 * Double(unit.perSecond)).rounded(.towardZero)
            guard ticks.magnitude < Double(Int64.max) else {
                throw FormatError(message: "That date is too far from 1970 to count in \(unit.rawValue.lowercased()).")
            }
            return String(Int64(ticks))
        }
        throw FormatError(message: "Not an ISO 8601 date: expected something like 2023-11-14T22:13:20Z.")
    }

    /// ISO 8601 carries at most three fractional digits, so a microsecond or
    /// nanosecond value is shown to the millisecond. Better a rounded date than
    /// a silently dropped fraction.
    private static func string(from date: Date, fractional: Bool) -> String {
        var options: ISO8601DateFormatter.Options = [.withInternetDateTime]
        if fractional { options.insert(.withFractionalSeconds) }
        return formatter(with: options).string(from: date)
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
