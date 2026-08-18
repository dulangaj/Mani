import Foundation

/// One named action in a bottom-bar menu. It erases the difference between a
/// non-failing `Transform`, a throwing `Conversion`, and the parameterised
/// formatters and digests, so the view has a single code path and the menus
/// have a single source of truth.
nonisolated struct TextOperation: Identifiable, Sendable {
    let id: String
    let label: String
    let help: String
    /// The content kinds this operation reads, or `nil` when it takes any text
    /// at all. Only set it where detection can positively recognise the input:
    /// an empty set here means "always offer this", not "never".
    let kinds: Set<ContentKind>?
    let run: @Sendable (String) throws -> String

    init(id: String, label: String, help: String, kinds: Set<ContentKind>? = nil,
         run: @escaping @Sendable (String) throws -> String) {
        self.id = id
        self.label = label
        self.help = help
        self.kinds = kinds
        self.run = run
    }

    init(_ transform: Transform, kinds: Set<ContentKind>? = nil) {
        self.init(id: "transform.\(transform)", label: transform.label, help: transform.help, kinds: kinds) {
            transform.apply(to: $0)
        }
    }

    init(_ conversion: Conversion, kinds: Set<ContentKind>? = nil) {
        self.init(id: "conversion.\(conversion)", label: conversion.label, help: conversion.help, kinds: kinds) {
            try conversion.apply(to: $0)
        }
    }

    /// Unknown content enables everything, because the guess is a heuristic and
    /// a wrong guess must never be able to hide an operation you wanted.
    func isEnabled(for kind: ContentKind?) -> Bool {
        guard let kind, let kinds else { return true }
        return kinds.contains(kind)
    }
}

/// The bottom bar's contents, in display order. Menus are a view over this and
/// nothing else; `Transform` no longer carries its own grouping, because the
/// grouping now spans three sources and has to live in exactly one place.
///
/// The three menus split along the only axis a user cares about: `Format` says
/// "this is structured data, make it readable", `Text` says "this is text,
/// reshape it", and `Convert` says "this is a value in some encoding,
/// re-represent it". Decode always precedes encode, matching reality — you
/// receive the gross thing more often than you produce it.
nonisolated enum Menus {
    /// HTML is offered to the XML formatters too: it often parses, and refusing
    /// to try is worse than the error banner you get when it does not.
    private static let markup: Set<ContentKind> = [.xml, .html]

    static let format: [[TextOperation]] = [
        [
            TextOperation(id: "format.json", label: "Format JSON",
                          help: "Pretty-print JSON, preserving key order", kinds: [.json]) { try Formatter.json($0) },
            TextOperation(id: "format.jsonSorted", label: "Format JSON (Sort Keys)",
                          help: "Pretty-print JSON with every object's keys sorted", kinds: [.json]) { try Formatter.json($0, sortKeys: true) },
            TextOperation(id: "format.jsonMinified", label: "Minify JSON",
                          help: "Strip all whitespace outside strings", kinds: [.json]) { try Formatter.minifiedJSON($0) },
        ],
        [
            TextOperation(id: "format.xml", label: "Format XML",
                          help: "Pretty-print XML, preserving attribute order", kinds: markup) { try Formatter.xml($0) },
            TextOperation(id: "format.xmlSorted", label: "Format XML (Sort Attributes)",
                          help: "Pretty-print XML with every element's attributes sorted", kinds: markup) { try Formatter.xml($0, sortAttributes: true) },
            TextOperation(id: "format.xmlMinified", label: "Minify XML",
                          help: "Strip inter-element whitespace, producing one line", kinds: markup) { try Formatter.minifiedXML($0) },
        ],
    ]

    /// Ordered by blast radius: reorder the whole document, then fix
    /// whitespace, then strip junk, then rewrite individual letters.
    static let text: [[TextOperation]] = [
        operations(.sortLines, .sortLinesDescending, .reverseLines, .shuffleLines, .removeDuplicateLines, .numberLines),
        operations(.normalizeLineEndings, .removeNewlines, .joinLines, .removeEmptyLines, .trimLines, .collapseSpaces, .removeSpaces),
        operations(.stripANSI, .stripInvisibles),
        operations(.toUppercase, .toLowercase, .toTitleCase, .toCamelCase, .toPascalCase,
                   .toSnakeCase, .toKebabCase, .toConstantCase, .toSlug),
    ]

    static let convert: [[TextOperation]] = [
        [TextOperation(Conversion.base64Decode, kinds: [.base64]), TextOperation(Transform.base64Encode),
         TextOperation(Conversion.hexDecode, kinds: [.hex]), TextOperation(Transform.hexEncode)],
        [TextOperation(Transform.decodeURL), TextOperation(Transform.encodeURL),
         TextOperation(Transform.unescapeHTML), TextOperation(Transform.escapeHTML),
         TextOperation(Transform.unescapeJSONString), TextOperation(Transform.escapeJSONString),
         TextOperation(Transform.unescapeShell)],
    ]

    /// Rendered as the one submenu in the app. Four interchangeable variants of
    /// a single idea do not deserve four rows of a menu you are scanning.
    static let hashes: [TextOperation] = Digests.Algorithm.allCases.map { algorithm in
        TextOperation(
            id: "digest.\(algorithm.rawValue)",
            label: algorithm.rawValue,
            help: "Replace the text with its \(algorithm.rawValue) hash, over the UTF-8 bytes including any trailing newline"
        ) { Digests.hex($0, algorithm) }
    }

    static let decoders: [[TextOperation]] = [
        [TextOperation(Conversion.jwtDecode, kinds: [.jwt]),
         TextOperation(Conversion.timestampToDate, kinds: [.timestamp]),
         TextOperation(Conversion.dateToTimestamp, kinds: [.isoDate])],
    ]

    /// Flattened union, for the tests that check nothing was implemented and
    /// then forgotten on the way to a menu.
    static let all: [TextOperation] =
        format.flatMap { $0 } + text.flatMap { $0 } + convert.flatMap { $0 } + hashes + decoders.flatMap { $0 }

    private static func operations(_ transforms: Transform...) -> [TextOperation] {
        transforms.map { TextOperation($0) }
    }
}
