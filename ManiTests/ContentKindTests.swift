import Foundation
import Testing
@testable import Mani

@Suite("Content Kind")
struct ContentKindTests {

    @Test func detectsJSONObjectAndArray() {
        #expect(ContentKind.detect(#"{"a": 1}"#) == .json)
        #expect(ContentKind.detect("[1, 2]") == .json)
    }

    @Test func invalidJSONIsNotJSON() {
        #expect(ContentKind.detect("{not json}") == nil)
    }

    @Test func detectsXMLAndHTML() {
        #expect(ContentKind.detect("<a href=\"x\">hi</a>") == .xml)
        #expect(ContentKind.detect("<!DOCTYPE html><html></html>") == .html)
    }

    @Test func detectsJWT() {
        #expect(ContentKind.detect("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig-part_1") == .jwt)
    }

    @Test func detectsTimestampDateHexBase64AndURL() {
        #expect(ContentKind.detect("1700000000") == .timestamp)
        #expect(ContentKind.detect("2023-11-14") == .isoDate)
        #expect(ContentKind.detect("2023-11-14T22:13:20Z") == .isoDate)
        #expect(ContentKind.detect("deadbeef00") == .hex)
        #expect(ContentKind.detect("SGVsbG8sIHdvcmxkIQ==") == .base64)
        #expect(ContentKind.detect("https://example.com/a?b=c") == .url)
    }

    @Test func plainProseAndOrdinaryWordsMatchNothing() {
        #expect(ContentKind.detect("hello, world") == nil)
        #expect(ContentKind.detect("") == nil)
        #expect(ContentKind.detect("antidisestablishmentarianism") == nil)
        #expect(ContentKind.detect("12345678") == nil)
    }

    // Guessing on a huge paste would cost more than the label is worth.
    @Test func veryLargeTextIsNotGuessed() {
        let big = "[" + Array(repeating: "1", count: 200_000).joined(separator: ",") + "]"
        #expect(ContentKind.detect(big) == nil)
    }

    @Test func statusBarAppendsTheKind() {
        #expect(TextStats.summary(for: "[1]", kind: .json) == "3 characters · 1 word · 1 line · JSON")
        #expect(TextStats.summary(for: "[1]") == "3 characters · 1 word · 1 line")
    }
}

@Suite("Command Availability")
struct CommandAvailabilityTests {

    private func command(_ id: String) throws -> TextOperation {
        try #require(Menus.all.first { $0.id == id })
    }

    @Test func formattersAreOfferedOnlyForTheirOwnKind() throws {
        #expect(try command("format.json").isEnabled(for: .json))
        #expect(try !command("format.json").isEnabled(for: .xml))
        #expect(try command("format.xml").isEnabled(for: .xml))
        #expect(try !command("format.xml").isEnabled(for: .json))
    }

    // HTML often parses as XML, and the error banner is a better answer than
    // refusing to try.
    @Test func xmlFormattersAcceptHTML() throws {
        #expect(try command("format.xmlSorted").isEnabled(for: .html))
    }

    @Test func decodersRequireTheEncodingTheyDecode() throws {
        #expect(try command("conversion.jwtDecode").isEnabled(for: .jwt))
        #expect(try !command("conversion.jwtDecode").isEnabled(for: .base64))
        #expect(try command("conversion.timestampToDate").isEnabled(for: .timestamp))
        #expect(try command("conversion.dateToTimestamp").isEnabled(for: .isoDate))
    }

    // A wrong guess must never be able to hide an operation, so anything we
    // cannot identify offers the lot.
    @Test func unknownContentEnablesEverything() {
        #expect(Menus.all.allSatisfy { $0.isEnabled(for: nil) })
    }

    @Test func textAndEncodeOperationsSurviveEveryKind() throws {
        let alwaysOffered = ["transform.toUppercase", "transform.base64Encode", "digest.SHA-256"]
        for id in alwaysOffered {
            let operation = try command(id)
            #expect(ContentKind.allCases.allSatisfy { operation.isEnabled(for: $0) })
        }
    }
}

@Suite("Command Search")
struct CommandSearchTests {

    private func labels(_ query: String) -> [String] {
        CommandSearch.matches(Menus.all, query: query).map(\.label)
    }

    @Test func anEmptyQueryKeepsMenuOrder() {
        #expect(CommandSearch.matches(Menus.all, query: "").map(\.id) == Menus.all.map(\.id))
    }

    // "fjs" is not this test's query on purpose: it matches plain "Format JSON"
    // too, through the S in JSON, and ranking that first is correct.
    @Test func initialsFindTheCommand() {
        #expect(labels("fjsk") == ["Format JSON (Sort Keys)"])
        #expect(labels("fjs").first == "Format JSON")
    }

    @Test func aPrefixOutranksALaterMatch() {
        #expect(labels("min").first == "Minify JSON")
    }

    @Test func matchingIsCaseAndSpaceInsensitive() {
        #expect(labels("FORMAT XML").first == "Format XML")
    }

    @Test func lettersMustAppearInOrder() {
        #expect(labels("nosj").isEmpty)
        #expect(labels("zzz").isEmpty)
    }

    @Test func everyResultContainsAllTheLetters() {
        for label in labels("se") {
            var remaining = Array("se")
            for character in label.lowercased() where character == remaining.first {
                remaining.removeFirst()
            }
            #expect(remaining.isEmpty)
        }
    }
}
