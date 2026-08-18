// Contract tests for the throwing conversions.
//
// Decisions pinned here:
//   * A JWT decodes to one JSON object, {"header": …, "payload": …}, so the
//     output is itself valid JSON that Mani's other actions can chew on.
//   * The signature is never verified and claim timestamps are never expanded.
//   * Timestamps are UTC, ISO 8601, whole seconds. Values too large to be
//     seconds are read as milliseconds.
//   * The whole selection is one value; timestamps embedded in a log are not
//     rewritten in place.
//   * There is deliberately no uniform empty-input rule here: the two decoders
//     that can round-trip empty do, and the other three reject it.

import Testing
@testable import Mani

@Suite("Conversion Contract")
struct ConversionContractTests {

    @Test(arguments: Conversion.allCases)
    func everyCaseIsDescribed(conversion: Conversion) {
        #expect(!conversion.label.isEmpty)
        #expect(!conversion.help.isEmpty)
    }

    @Test func idsAreUnique() {
        #expect(Set(Conversion.allCases.map { "\($0)" }).count == Conversion.allCases.count)
    }

    @Test(arguments: [Conversion.jwtDecode, .timestampToDate, .dateToTimestamp])
    func conversionsThatRejectEmptyInput(conversion: Conversion) {
        #expect(throws: FormatError.self) { try conversion.apply(to: "") }
    }
}

@Suite("JSON Web Tokens")
struct JWTTests {

    // Header {"alg":"HS256","typ":"JWT"}, payload with three claims, and a
    // signature segment that is deliberately meaningless.
    private static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        + ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFkYSIsImlhdCI6MTUxNjIzOTAyMn0"
        + ".c2lnbmF0dXJl"

    @Test func decodesHeaderAndPayloadIntoOneObject() throws {
        #expect(try Conversion.jwtDecode.apply(to: Self.token) == """
            {
              "header": {
                "alg": "HS256",
                "typ": "JWT"
              },
              "payload": {
                "sub": "1234567890",
                "name": "Ada",
                "iat": 1516239022
              }
            }
            """)
    }

    // The point of emitting JSON rather than two blobs: the result composes
    // with everything else in the app.
    @Test func theResultIsItselfValidJSON() throws {
        let decoded = try Conversion.jwtDecode.apply(to: Self.token)
        let minified = try Formatter.minifiedJSON(decoded)
        #expect(minified.hasPrefix(#"{"header":{"alg":"HS256""#))
    }

    @Test func surroundingWhitespaceIsTolerated() throws {
        let padded = "  \(Self.token)\n"
        #expect(try Conversion.jwtDecode.apply(to: padded) == Conversion.jwtDecode.apply(to: Self.token))
    }

    // There is nowhere to type a secret, so the signature is not checked.
    @Test func aGarbageSignatureStillDecodes() throws {
        let tampered = Self.token.split(separator: ".").prefix(2).joined(separator: ".") + ".bm90YXNpZw"
        #expect(try Conversion.jwtDecode.apply(to: tampered) == Conversion.jwtDecode.apply(to: Self.token))
    }

    @Test func rejectsSomethingThatIsNotThreeSegments() {
        #expect(throws: FormatError.self) { try Conversion.jwtDecode.apply(to: "abc.def") }
        #expect(throws: FormatError.self) { try Conversion.jwtDecode.apply(to: "a.b.c.d") }
    }

    @Test func rejectsASegmentThatIsNotBase64() {
        #expect(throws: FormatError.self) { try Conversion.jwtDecode.apply(to: "!!!.eyJhIjoxfQ.sig") }
    }

    @Test func rejectsASegmentThatIsNotJSON() {
        // "hello" and "world", base64url encoded — valid base64, invalid JSON.
        #expect(throws: FormatError.self) { try Conversion.jwtDecode.apply(to: "aGVsbG8.d29ybGQ.sig") }
    }
}

@Suite("Timestamps")
struct TimestampTests {

    @Test(arguments: [
        ("1700000000", "2023-11-14T22:13:20Z"),
        ("0", "1970-01-01T00:00:00Z"),
        ("-86400", "1969-12-31T00:00:00Z"),
        ("1516239022", "2018-01-18T01:30:22Z"),
    ])
    func secondsBecomeAnISODate(input: String, expected: String) throws {
        #expect(try Conversion.timestampToDate.apply(to: input) == expected)
    }

    @Test func surroundingWhitespaceIsTolerated() throws {
        #expect(try Conversion.timestampToDate.apply(to: "  1700000000\n") == "2023-11-14T22:13:20Z")
    }

    // 1e11 seconds is the year 5138, so nothing real collides with the
    // millisecond range.
    @Test func millisecondsAreDetectedByMagnitude() throws {
        #expect(try Conversion.timestampToDate.apply(to: "1700000000000") == "2023-11-14T22:13:20Z")
    }

    @Test func subSecondPrecisionIsTruncated() throws {
        #expect(try Conversion.timestampToDate.apply(to: "1700000000.75") == "2023-11-14T22:13:20Z")
    }

    @Test func rejectsAnythingThatIsNotANumber() {
        #expect(throws: FormatError.self) { try Conversion.timestampToDate.apply(to: "yesterday") }
        #expect(throws: FormatError.self) { try Conversion.timestampToDate.apply(to: "17 00") }
    }

    // One value per conversion; rewriting a whole log is a different feature.
    @Test func rejectsMultipleValues() {
        #expect(throws: FormatError.self) { try Conversion.timestampToDate.apply(to: "1700000000\n1700000001") }
    }

    @Test func isoDatesBecomeSeconds() throws {
        #expect(try Conversion.dateToTimestamp.apply(to: "2023-11-14T22:13:20Z") == "1700000000")
    }

    @Test func fractionalSecondsAreAccepted() throws {
        #expect(try Conversion.dateToTimestamp.apply(to: "2023-11-14T22:13:20.500Z") == "1700000000")
    }

    @Test func nonUTCOffsetsAreAccepted() throws {
        #expect(try Conversion.dateToTimestamp.apply(to: "2023-11-14T23:13:20+01:00") == "1700000000")
    }

    @Test func aBareDateIsMidnightUTC() throws {
        #expect(try Conversion.dateToTimestamp.apply(to: "2023-11-14") == "1699920000")
    }

    // Always seconds out, never milliseconds, whichever way you came in.
    @Test func outputIsAlwaysSeconds() throws {
        let iso = try Conversion.timestampToDate.apply(to: "1700000000000")
        #expect(try Conversion.dateToTimestamp.apply(to: iso) == "1700000000")
    }

    @Test func rejectsSomethingThatIsNotADate() {
        #expect(throws: FormatError.self) { try Conversion.dateToTimestamp.apply(to: "14/11/2023") }
        #expect(throws: FormatError.self) { try Conversion.dateToTimestamp.apply(to: "not a date") }
    }

    @Test(arguments: ["0", "1", "1700000000", "-86400", "1516239022", "2147483647"])
    func secondsRoundTripThroughISO(seconds: String) throws {
        let iso = try Conversion.timestampToDate.apply(to: seconds)
        #expect(try Conversion.dateToTimestamp.apply(to: iso) == seconds)
    }
}
