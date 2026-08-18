// Contract tests for the line-oriented operations.
//
// Decisions pinned here:
//   * A trailing newline survives as a trailing newline and never becomes an
//     empty last line. This differs from the older removeEmptyLines, which
//     drops it — that behaviour is documented and tested and is left alone.
//   * Any line operation normalizes CR and CRLF to LF, as a side effect of
//     splitting and rejoining.
//   * Sorting is case-insensitive, numeric, and locale-independent, tiebroken
//     by Unicode scalar order so the ordering is total.
//   * Dedupe keeps the first occurrence, preserves order, compares exactly,
//     and does collapse repeated blank lines.

import Foundation
import Testing
@testable import Mani

/// Seeded generator so shuffle tests are deterministic. The exact permutation
/// is deliberately not pinned: it depends on the standard library's shuffle
/// implementation, which is not a stability guarantee across Swift versions.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite("Line Ordering")
struct LineOrderingTests {

    // MARK: - Trailing newlines

    @Test func sortPreservesTrailingNewlineWithoutMakingAnEmptyLine() {
        #expect(Transform.sortLines.apply(to: "b\na\n") == "a\nb\n")
    }

    @Test func sortWithoutTrailingNewlineStaysWithout() {
        #expect(Transform.sortLines.apply(to: "b\na") == "a\nb")
    }

    @Test func reversePreservesTrailingNewline() {
        #expect(Transform.reverseLines.apply(to: "a\nb\n") == "b\na\n")
    }

    @Test func dedupePreservesTrailingNewline() {
        #expect(Transform.removeDuplicateLines.apply(to: "a\na\n") == "a\n")
    }

    // The older transform's contrary behaviour is deliberately unchanged.
    @Test func removeEmptyLinesStillDropsTheTrailingBlank() {
        #expect(Transform.removeEmptyLines.apply(to: "a\nb\n") == "a\nb")
    }

    @Test func aLoneNewlineIsOneEmptyLine() {
        #expect(Transform.sortLines.apply(to: "\n") == "\n")
    }

    @Test(arguments: [
        Transform.sortLines, .sortLinesDescending, .reverseLines,
        .removeDuplicateLines, .numberLines, .shuffleLines,
    ])
    func lineOperationsNormalizeCRLF(transform: Transform) {
        #expect(!transform.apply(to: "a\r\nb").contains("\r"))
    }

    // MARK: - Sorting

    @Test func sortIsCaseInsensitive() {
        #expect(Transform.sortLines.apply(to: "banana\nApple\ncherry") == "Apple\nbanana\ncherry")
    }

    @Test func sortOrdersEmbeddedNumbersNaturally() {
        #expect(Transform.sortLines.apply(to: "file10\nfile2\nfile1") == "file1\nfile2\nfile10")
    }

    // Case-insensitive comparison alone leaves "a" and "A" tied; the scalar
    // tiebreak makes the result total and reproducible.
    @Test func sortIsTotalForLinesEqualApartFromCase() {
        #expect(Transform.sortLines.apply(to: "a\nA") == "A\na")
        #expect(Transform.sortLines.apply(to: "A\na") == "A\na")
    }

    @Test func sortIsIdempotent() {
        let once = Transform.sortLines.apply(to: "delta\nAlpha\ncharlie\nbravo")
        #expect(Transform.sortLines.apply(to: once) == once)
    }

    @Test func sortTreatsLeadingWhitespaceAsSignificant() {
        #expect(Transform.sortLines.apply(to: "a\n  b") == "  b\na")
    }

    @Test func sortPutsEmptyLinesFirst() {
        #expect(Transform.sortLines.apply(to: "b\n\na") == "\na\nb")
    }

    @Test func descendingIsTheExactReverseOfAscending() {
        let input = "delta\nAlpha\ncharlie\nbravo"
        let ascending = Transform.sortLines.apply(to: input)
        let descending = Transform.sortLinesDescending.apply(to: input)
        #expect(descending == ascending.split(separator: "\n").reversed().joined(separator: "\n"))
    }

    @Test func sortingASingleLineChangesNothing() {
        #expect(Transform.sortLines.apply(to: "only") == "only")
    }

    // MARK: - Reversing

    @Test func reverseFlipsLineOrder() {
        #expect(Transform.reverseLines.apply(to: "a\nb\nc") == "c\nb\na")
    }

    @Test func reverseDoesNotReverseCharacters() {
        #expect(Transform.reverseLines.apply(to: "abc") == "abc")
    }

    // MARK: - Dedupe

    @Test func dedupeKeepsTheFirstOccurrenceAndPreservesOrder() {
        #expect(Transform.removeDuplicateLines.apply(to: "b\na\nb\nc\na") == "b\na\nc")
    }

    @Test func dedupeIsCaseSensitive() {
        #expect(Transform.removeDuplicateLines.apply(to: "a\nA") == "a\nA")
    }

    @Test func dedupeIsWhitespaceSensitive() {
        #expect(Transform.removeDuplicateLines.apply(to: "a\na ") == "a\na ")
    }

    @Test func dedupeCollapsesRepeatedBlankLines() {
        #expect(Transform.removeDuplicateLines.apply(to: "a\n\n\nb") == "a\n\nb")
    }

    // MARK: - Numbering

    @Test func numberLinesIsOneBasedWithADotSeparator() {
        #expect(Transform.numberLines.apply(to: "a\nb") == "1. a\n2. b")
    }

    @Test func numberLinesRightAlignsPastNine() {
        let input = (1...10).map { "line\($0)" }.joined(separator: "\n")
        let output = Transform.numberLines.apply(to: input)
        let lines = output.split(separator: "\n")
        #expect(lines.first == " 1. line1")
        #expect(lines.last == "10. line10")
    }

    @Test func numberLinesNumbersBlankLinesToo() {
        #expect(Transform.numberLines.apply(to: "a\n\nb") == "1. a\n2. \n3. b")
    }

    @Test func numberLinesPreservesTrailingNewline() {
        #expect(Transform.numberLines.apply(to: "a\n") == "1. a\n")
    }

    // MARK: - Shuffling

    @Test func shuffleIsAPermutation() {
        let input = "a\nb\nc\nd\ne\nf\ng\nh"
        let output = Transform.shuffleLines.apply(to: input)
        #expect(output.split(separator: "\n").sorted() == input.split(separator: "\n").sorted())
    }

    @Test func shufflePreservesLineCount() {
        let input = "a\nb\nc\nd\ne"
        #expect(Transform.shuffleLines.apply(to: input).split(separator: "\n").count == 5)
    }

    @Test func shufflingOneLineChangesNothing() {
        #expect(Transform.shuffleLines.apply(to: "only") == "only")
    }

    @Test func shuffleIsDeterministicForAGivenSeed() {
        let input = "a\nb\nc\nd\ne\nf\ng\nh"
        var first = SeededGenerator(seed: 42)
        var second = SeededGenerator(seed: 42)
        #expect(Lines.shuffled(input, using: &first) == Lines.shuffled(input, using: &second))
    }

    @Test func shuffleActuallyReorders() {
        let input = (1...12).map(String.init).joined(separator: "\n")
        var generator = SeededGenerator(seed: 7)
        #expect(Lines.shuffled(input, using: &generator) != input)
    }

    @Test func shufflePreservesTrailingNewline() {
        var generator = SeededGenerator(seed: 1)
        #expect(Lines.shuffled("a\nb\n", using: &generator).hasSuffix("\n"))
    }
}
