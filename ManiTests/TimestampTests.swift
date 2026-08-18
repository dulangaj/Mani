// Contract tests for the unit-stated timestamp conversions.
//
// Decisions pinned here:
//   * The unit named by the command is obeyed, never second-guessed.
//   * Arithmetic stays in Int64, so a nanosecond value keeps all 19 digits.
//   * ISO 8601 carries three fractional digits, so sub-millisecond input is
//     shown to the millisecond rather than dropped in silence.

import Foundation
import Testing
@testable import Mani

@Suite("Timestamp Units")
struct TimestampUnitTests {

    @Test func everyUnitReadsTheSameInstant() throws {
        #expect(try Timestamps.date(from: "1700000000", unit: .seconds) == "2023-11-14T22:13:20Z")
        #expect(try Timestamps.date(from: "1700000000000", unit: .milliseconds) == "2023-11-14T22:13:20Z")
        #expect(try Timestamps.date(from: "1700000000000000", unit: .microseconds) == "2023-11-14T22:13:20Z")
        #expect(try Timestamps.date(from: "1700000000000000000", unit: .nanoseconds) == "2023-11-14T22:13:20Z")
    }

    @Test func everyUnitWritesTheSameInstant() throws {
        let iso = "2023-11-14T22:13:20Z"
        #expect(try Timestamps.timestamp(from: iso, unit: .seconds) == "1700000000")
        #expect(try Timestamps.timestamp(from: iso, unit: .milliseconds) == "1700000000000")
        #expect(try Timestamps.timestamp(from: iso, unit: .microseconds) == "1700000000000000")
        #expect(try Timestamps.timestamp(from: iso, unit: .nanoseconds) == "1700000000000000000")
    }

    @Test(arguments: TimestampUnit.allCases)
    func roundTripsThroughISO(unit: TimestampUnit) throws {
        let ticks = String(1_700_000_000 * unit.perSecond)
        let iso = try Timestamps.date(from: ticks, unit: unit)
        #expect(try Timestamps.timestamp(from: iso, unit: unit) == ticks)
    }

    // The stated unit wins: this is the whole point of the submenu.
    @Test func aStatedUnitIsNotSecondGuessedByMagnitude() throws {
        #expect(try Timestamps.date(from: "1700000000", unit: .milliseconds) == "1970-01-20T16:13:20Z")
        #expect(try Timestamps.date(from: "1700000000000", unit: .seconds) == "55840-11-08T22:13:20Z")
    }

    @Test func subSecondValuesKeepMillisecondPrecision() throws {
        #expect(try Timestamps.date(from: "1700000000500", unit: .milliseconds) == "2023-11-14T22:13:20.500Z")
        #expect(try Timestamps.date(from: "1700000000123456789", unit: .nanoseconds) == "2023-11-14T22:13:20.123Z")
    }

    @Test func negativeValuesPredate1970() throws {
        #expect(try Timestamps.date(from: "-86400000", unit: .milliseconds) == "1969-12-31T00:00:00Z")
    }

    @Test func rejectsWhatIsNotANumber() {
        for unit in TimestampUnit.allCases {
            #expect(throws: FormatError.self) { try Timestamps.date(from: "0x10", unit: unit) }
            #expect(throws: FormatError.self) { try Timestamps.date(from: "1e5", unit: unit) }
            #expect(throws: FormatError.self) { try Timestamps.date(from: "yesterday", unit: unit) }
        }
    }

    @Test func rejectsADateTooFarOutToCount() {
        #expect(throws: FormatError.self) {
            try Timestamps.timestamp(from: "9999-12-31T00:00:00Z", unit: .nanoseconds)
        }
    }
}

@Suite("Timestamp Auto-Detection")
struct TimestampAutoDetectionTests {

    // Every rung is a thousand-plus years past anything real, so a value large
    // enough to be the next unit up always is one.
    @Test func theUnitIsInferredUpThroughNanoseconds() throws {
        for ticks in ["1700000000", "1700000000000", "1700000000000000", "1700000000000000000"] {
            #expect(try Conversion.timestampToDate.apply(to: ticks) == "2023-11-14T22:13:20Z")
        }
    }
}
