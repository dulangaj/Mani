// Contract tests for the bottom bar's registry.
//
// These exist because the app cannot be launched from a test run. An operation
// that is implemented and then never wired into a menu is otherwise completely
// invisible, and a duplicated label or an empty group renders as a subtly
// broken menu rather than as a failure.

import Foundation
import Testing
@testable import Mani

@Suite("Menus")
struct MenuTests {

    private static let groups: [[TextOperation]] =
        Menus.format + Menus.text + Menus.convert + Menus.decoders + [Menus.hashes]

    @Test func idsAreUnique() {
        #expect(Set(Menus.all.map(\.id)).count == Menus.all.count)
    }

    // A duplicated label is a copy-paste slip that would otherwise ship.
    @Test func labelsAreUnique() {
        #expect(Set(Menus.all.map(\.label)).count == Menus.all.count)
    }

    @Test(arguments: Menus.all)
    func everyOperationIsDescribed(operation: TextOperation) {
        #expect(!operation.label.isEmpty)
        #expect(!operation.help.isEmpty)
    }

    // An empty group renders as two dividers in a row.
    @Test func noGroupIsEmpty() {
        #expect(Self.groups.allSatisfy { !$0.isEmpty })
    }

    // The tripwire that makes adding a case a menu decision.
    @Test func everyTransformAppearsInExactlyOneMenu() {
        for transform in Transform.allCases {
            let matches = Menus.all.filter { $0.id == "transform.\(transform)" }
            #expect(matches.count == 1, "\(transform) is in \(matches.count) menus")
        }
    }

    @Test func everyConversionAppearsInExactlyOneMenu() {
        for conversion in Conversion.allCases {
            let matches = Menus.all.filter { $0.id == "conversion.\(conversion)" }
            #expect(matches.count == 1, "\(conversion) is in \(matches.count) menus")
        }
    }

    @Test func everyHashAlgorithmIsOffered() {
        #expect(Menus.hashes.count == Digests.Algorithm.allCases.count)
    }

    // Loud on a bad merge.
    @Test func menuSizesAreAsDesigned() {
        #expect(Menus.format.flatMap { $0 }.count == 6)
        #expect(Menus.text.flatMap { $0 }.count == 24)
        #expect(Menus.convert.flatMap { $0 }.count == 11)
        #expect(Menus.decoders.flatMap { $0 }.count == 3)
        #expect(Menus.hashes.count == 4)
        #expect(Menus.all.count == 48)
    }

    // The cheapest available substitute for launching the app: nothing in any
    // menu may crash, and nothing may throw an error the banner cannot show.
    @Test func everyOperationSurvivesTheCorpus() {
        let corpus = ["", "hello", "a\nb\n", "  spaced  ", #"{"a":1}"#, "<x/>", "\u{1F642} ok", "\u{1B}[1mx\u{1B}[0m"]
        for operation in Menus.all {
            for input in corpus {
                do {
                    _ = try operation.run(input)
                } catch let error as FormatError {
                    #expect(!error.message.isEmpty, "\(operation.id) threw an empty message")
                } catch {
                    Issue.record("\(operation.id) threw \(type(of: error)) on \(input.debugDescription)")
                }
            }
        }
    }
}
