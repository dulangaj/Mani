import Testing
import Foundation
@testable import Mani

private func pattern(_ text: String, _ mode: MatchMode = .plain,
                     caseSensitive: Bool = false, wholeWord: Bool = false) -> FindPattern {
    FindPattern(text: text, mode: mode, isCaseSensitive: caseSensitive, isWholeWord: wholeWord)
}

/// The matched text, which is what a reader of a failing test wants to see.
private func hits(_ pattern: FindPattern, in text: String) throws -> [String] {
    try pattern.ranges(in: text).map { (text as NSString).substring(with: $0) }
}

/// Location and length in UTF-16 units, which is what `NSTextView` is handed.
private func spans(_ pattern: FindPattern, in text: String) throws -> [[Int]] {
    try pattern.ranges(in: text).map { [$0.location, $0.length] }
}

@Suite("Find patterns")
struct FindPatternTests {
    @Test func findsEveryLiteralOccurrence() throws {
        #expect(try spans(pattern("ab"), in: "ab cab ab") == [[0, 2], [4, 2], [7, 2]])
    }

    @Test func literalsAreNotPatterns() throws {
        #expect(try hits(pattern("a.c"), in: "abc a.c") == ["a.c"])
    }

    /// Every character a regular expression would read specially has to survive
    /// plain mode intact, since that is the whole promise of the Text button.
    @Test(arguments: [
        "(", "[", "*", "\\", "a{2,1}", "a**", "?", "+", "$", "^", "|", ".", "()", "[]",
    ])
    func metacharactersAreLiteralInPlainMode(_ needle: String) throws {
        let text = "x\(needle)y"
        #expect(try hits(pattern(needle), in: text) == [needle])
    }

    @Test(arguments: ["(", "[", "*", "\\", "a{2,1}", "a**", "(?<foo", "(?P<x>a)"])
    func theSameStringsAreErrorsInRegexMode(_ needle: String) {
        #expect(throws: (any Error).self) { try pattern(needle, .regex).ranges(in: "x\(needle)y") }
    }

    @Test func emptyPatternMatchesNothing() throws {
        #expect(try FindPattern().ranges(in: "anything").isEmpty)
    }

    /// A pattern that can match nothing at all reports no hits rather than one
    /// between every pair of characters.
    @Test(arguments: ["x*", "^", "\\b", "(?=a)"])
    func zeroWidthMatchesAreDropped(_ needle: String) throws {
        #expect(try pattern(needle, .regex).ranges(in: "abc").isEmpty)
    }
}

/// The text this app is actually pointed at: notes, logs, and pasted Markdown.
@Suite("Find patterns, real text")
struct FindRealTextTests {
    private let notes = """
        See [the docs](https://example.com/a_b?x=1&y=2) and [issue 42](http://jira.local/ABC-42).
        Run `swift build`, then `swift test`; binaries land in C:\\Users\\me\\bin or /usr/local/bin.
        Costs 3.50 USD across 42 items and 1000000 rows.
        """

    @Test func stripsMarkdownLinkPunctuation() throws {
        #expect(try hits(pattern("["), in: notes) == ["[", "["])
        #expect(try hits(pattern("]("), in: notes) == ["](", "]("])
    }

    /// The everyday use: keep the link text, drop the target.
    @Test func stripsTheTargetOutOfAMarkdownLink() throws {
        let targets = pattern(#"\]\([^)]*\)"#, .regex)
        #expect(try hits(targets, in: notes) == ["](https://example.com/a_b?x=1&y=2)", "](http://jira.local/ABC-42)"])
    }

    @Test func stripsWholeMarkdownLinks() throws {
        let links = pattern(#"\[([^\]]+)\]\([^)]+\)"#, .regex)
        #expect(try hits(links, in: notes)
            == ["[the docs](https://example.com/a_b?x=1&y=2)", "[issue 42](http://jira.local/ABC-42)"])
    }

    @Test func stripsBareURLs() throws {
        #expect(try hits(pattern(#"https?://[^\s)]+"#, .regex), in: notes)
            == ["https://example.com/a_b?x=1&y=2", "http://jira.local/ABC-42"])
    }

    @Test(arguments: [
        (#"\d+"#, ["1", "2", "42", "42", "3", "50", "42", "1000000"]),
        (#"\d+\.\d+"#, ["3.50"]),
        (#"\b\d{4,}\b"#, ["1000000"]),
    ])
    func stripsNumbers(_ needle: String, _ expected: [String]) throws {
        #expect(try hits(pattern(needle, .regex), in: notes) == expected)
    }

    @Test func stripsSlashesAndBackslashesLiterally() throws {
        #expect(try hits(pattern("\\"), in: notes).count == 3)
        #expect(try hits(pattern("/"), in: notes).count == 9)
        #expect(try hits(pattern("//"), in: notes).count == 2)
    }

    @Test func stripsBackticksAndTheCodeInThem() throws {
        #expect(try hits(pattern("`"), in: notes).count == 4)
        #expect(try hits(pattern("`[^`]+`", .regex), in: notes) == ["`swift build`", "`swift test`"])
    }

    /// A tab-and-space log line, the other thing that gets pasted in here.
    @Test func collapsesRunsOfWhitespace() throws {
        let log = "2026-08-18 23:13:19.567  WARN \tretrying   in 5s"
        #expect(try hits(pattern(#"[ \t]{2,}"#, .regex), in: log) == ["  ", " \t", "   "])
        #expect(try spans(pattern(#"^\S+ \S+"#, .regex), in: log) == [[0, 23]])
    }
}

/// The ranges go straight to `NSTextView`, which counts in UTF-16, while Swift
/// counts in characters. Everything here would be off by one or worse if the
/// two were ever confused.
@Suite("Find patterns, offsets")
struct FindOffsetTests {
    @Test(arguments: [
        ("b", "a😀b😀c", [[3, 1]]),
        ("😀", "a😀b😀c", [[1, 2], [4, 2]]),
        ("y", "x👨‍👩‍👧‍👦y", [[12, 1]]),
        ("B", "A🇺🇸B", [[5, 1]]),
        ("🇺🇸", "A🇺🇸B", [[1, 4]]),
        ("é", "café", [[3, 1]]),
    ])
    func offsetsAreUTF16NotCharacters(_ needle: String, _ text: String, _ expected: [[Int]]) throws {
        #expect(try spans(pattern(needle), in: text) == expected)
    }

    @Test func adjacentMatchesNeitherOverlapNorSkip() throws {
        #expect(try spans(pattern("aa"), in: "aaaa") == [[0, 2], [2, 2]])
    }

    @Test func overlappingCandidatesYieldTheLeftmostOnly() throws {
        #expect(try spans(pattern("aba"), in: "ababa") == [[0, 3]])
    }

    @Test func matchesTheDocumentEdges() throws {
        #expect(try spans(pattern("x"), in: "xax") == [[0, 1], [2, 1]])
        #expect(try spans(pattern("abc"), in: "abc") == [[0, 3]])
    }

    @Test(arguments: [
        ("\n", "a\nb", [[1, 1]]),
        ("b\nc", "a\nb\nc\nd", [[2, 3]]),
        ("\r\n", "a\nb", [[Int]]()),
    ])
    func literalsCrossLines(_ needle: String, _ text: String, _ expected: [[Int]]) throws {
        #expect(try spans(pattern(needle), in: text) == expected)
    }

    /// The invariant `EditorController.replace` rests on: it deletes back to
    /// front, which corrupts the text the moment two ranges overlap.
    @Test(arguments: ["a*", "\\b", "(?=.)", ".*", "a|aa", "(a)(?=a)", "\\w*", "[\\s\\S]*", "x?", "\\X"])
    func rangesAreAscendingAndDisjoint(_ needle: String) throws {
        let corpus = "aaa bbb aaa\n😀é\r\ncat concat CAT 42 ..."
        let found = try pattern(needle, .regex).ranges(in: corpus)
        #expect(zip(found, found.dropFirst()).allSatisfy { NSMaxRange($0) <= $1.location })
    }
}

@Suite("Find patterns, case")
struct FindCaseTests {
    @Test func loosensUntilCaseIsAsked() throws {
        #expect(try hits(pattern("log"), in: "log LOG Log") == ["log", "LOG", "Log"])
        #expect(try hits(pattern("log", caseSensitive: true), in: "log LOG Log") == ["log"])
    }

    /// Case folding is full, not one-to-one, so a match can be longer or shorter
    /// than the pattern that found it. The length has to come from the match.
    @Test(arguments: [
        ("ss", "ß", [[0, 1]]),
        ("ß", "SS", [[0, 2]]),
        ("k", "\u{212A}", [[0, 1]]),
        ("σ", "ς", [[0, 1]]),
    ])
    func foldsCaseFully(_ needle: String, _ text: String, _ expected: [[Int]]) throws {
        #expect(try spans(pattern(needle), in: text) == expected)
        #expect(try pattern(needle, caseSensitive: true).ranges(in: text).isEmpty)
    }

    /// Folding is locale-independent, and stays that way: under a Turkish locale
    /// `i` would fold to `İ` and strip the wrong letters.
    @Test func ignoresTheTurkishDottedPairs() throws {
        #expect(try spans(pattern("i"), in: "i I İ ı") == [[0, 1], [2, 1]])
        #expect(try pattern("I").ranges(in: "ı").isEmpty)
        #expect(try spans(pattern("İ"), in: "i I İ") == [[4, 1]])
    }

    @Test func leavesNormalizationAlone() throws {
        #expect(try pattern("\u{e9}").ranges(in: "e\u{301}cole").isEmpty)
        #expect(try pattern("e\u{301}").ranges(in: "\u{e9}").isEmpty)
    }

    /// The toggle sets an option; an inline flag in the pattern still wins.
    @Test func inlineFlagsOverrideTheToggle() throws {
        #expect(try hits(pattern("(?-i)Log", .regex), in: "log Log LOG") == ["Log"])
    }
}

@Suite("Find patterns, whole word")
struct FindWholeWordTests {
    @Test func skipsSubstrings() throws {
        #expect(try spans(pattern("cat", wholeWord: true), in: "cat concatenate cat.") == [[0, 3], [16, 3]])
    }

    @Test(arguments: ["cat here", "here cat", "cat"])
    func matchesAtTheDocumentEdges(_ text: String) throws {
        #expect(try hits(pattern("cat", wholeWord: true), in: text) == ["cat"])
    }

    @Test func keepsInteriorSpacesAndHyphens() throws {
        #expect(try spans(pattern("hello world", wholeWord: true), in: "say hello world now") == [[4, 11]])
        #expect(try spans(pattern("well-known", wholeWord: true), in: "a well-known fact") == [[2, 10]])
    }

    /// The boundaries wrap the whole pattern, not each branch of it.
    @Test func wrapsTheWholeAlternation() throws {
        #expect(try spans(pattern("cat|dog", .regex, wholeWord: true), in: "cat dogma dog") == [[0, 3], [10, 3]])
        #expect(try spans(pattern("ab*", .regex, wholeWord: true), in: "a abbb abc") == [[0, 1], [2, 4]])
    }

    /// Known limit, pinned rather than fixed: `\b` needs a word character on the
    /// pattern's own edge, so a pattern that starts or ends with punctuation
    /// finds nothing and the bar reports it as an ordinary miss.
    @Test(arguments: [(".net", "use .net here"), ("c++", "i know c++ well"), ("😀", "a 😀 b")])
    func findsNothingWhenThePatternEdgeIsNotAWord(_ needle: String, _ text: String) throws {
        #expect(try pattern(needle, wholeWord: true).ranges(in: text).isEmpty)
    }
}

@Suite("Find patterns, regex")
struct FindRegexTests {
    @Test(arguments: [
        (#"\d+"#, "a1 b22 c333", ["1", "22", "333"]),
        (#"(a)\1"#, "aa a aaa", ["aa", "aa"]),
        (#"foo(?=bar)"#, "foobar foobaz", ["foo"]),
        (#"(?<=x)y"#, "xy zy", ["y"]),
        (#"a*b*"#, "cab c", ["ab"]),
        (#"\R"#, "a\r\nb\nc", ["\r\n", "\n"]),
        (#"\w+"#, "café 😀", ["café"]),
        (#"."#, "a\nb", ["a", "b"]),
        (#"a\nb"#, "a\nb", ["a\nb"]),
        (#"a|"#, "xay", ["a"]),
    ])
    func readsTheUsualConstructs(_ needle: String, _ text: String, _ expected: [String]) throws {
        #expect(try hits(pattern(needle, .regex), in: text) == expected)
    }

    /// Known limit, pinned rather than fixed: the anchors address the document,
    /// not each line, until the pattern asks for line mode itself.
    @Test func anchorsSpanTheWholeDocument() throws {
        #expect(try spans(pattern("^a", .regex), in: "a\nab\na") == [[0, 1]])
        #expect(try spans(pattern("(?m)^a", .regex), in: "a\nab\na") == [[0, 1], [2, 1], [5, 1]])
    }
}

@Suite("Find controller")
@MainActor
struct FindControllerTests {
    private func controller(_ text: String, _ pattern: FindPattern) -> FindController {
        let controller = FindController()
        controller.pattern = pattern
        controller.refresh(in: text)
        return controller
    }

    @Test func reportsWhereItIsInTheList() {
        let controller = controller("a b a c a", pattern("a"))
        #expect(controller.status == "1 of 3")
        _ = controller.step(1)
        #expect(controller.status == "2 of 3")
    }

    @Test(arguments: [
        ("", MatchMode.plain, ""),
        ("(", .regex, "Bad pattern"),
        ("zzz", .plain, "No matches"),
    ])
    func wordsTheOtherStates(_ needle: String, _ mode: MatchMode, _ expected: String) {
        #expect(controller("a b a", pattern(needle, mode)).status == expected)
    }

    @Test func wrapsAtBothEnds() {
        let controller = controller("a b a c a", pattern("a"))
        #expect(controller.step(-1).map(\.location) == 8)
        #expect(controller.step(1).map(\.location) == 0)
    }

    /// A jump wider than the list stays inside it, rather than trapping on a
    /// negative index the way a bare `%` would.
    @Test func survivesAJumpWiderThanTheList() {
        let controller = controller("a b a c a", pattern("a"))
        #expect(controller.step(-5) != nil)
        #expect((0..<3).contains(controller.current))
        #expect(controller.step(7) != nil)
        #expect((0..<3).contains(controller.current))
    }

    @Test func hasNothingToStepThroughWithoutMatches() {
        let controller = controller("a b a", pattern("zzz"))
        #expect(controller.step(1) == nil)
        #expect(controller.currentMatch == nil)
    }

    /// Stripping a hit leaves the index where it was, so it now points at the
    /// hit that took its place and holding Return walks the document.
    @Test func keepsTheIndexAsTheListShrinks() {
        let controller = controller("a a a", pattern("a"))
        _ = controller.step(1)
        controller.refresh(in: "a a")
        #expect(controller.current == 1)
        controller.refresh(in: "")
        #expect(controller.current == 0)
        #expect(controller.currentMatch == nil)
    }

    /// Half-typed regular expressions are the normal case, not an error state.
    @Test func recoversFromAHalfTypedPattern() {
        let controller = controller("a b a", pattern("(", .regex))
        #expect(!controller.isPatternValid)
        #expect(controller.matches.isEmpty)
        controller.pattern = pattern("(a)", .regex)
        controller.refresh(in: "a b a")
        #expect(controller.isPatternValid)
        #expect(controller.status == "1 of 2")
    }
}
