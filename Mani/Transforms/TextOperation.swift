import Foundation

/// One named action in a bottom-bar menu. It erases the difference between a
/// non-failing `Transform`, a throwing `Conversion`, and the parameterised
/// formatters and digests, so the view has a single code path and the menus
/// have a single source of truth.
nonisolated struct TextOperation: Identifiable, Sendable {
    let id: String
    let label: String
    let help: String
    let run: @Sendable (String) throws -> String

    init(id: String, label: String, help: String, run: @escaping @Sendable (String) throws -> String) {
        self.id = id
        self.label = label
        self.help = help
        self.run = run
    }

    init(_ transform: Transform) {
        self.init(id: "transform.\(transform)", label: transform.label, help: transform.help) {
            transform.apply(to: $0)
        }
    }

    init(_ conversion: Conversion) {
        self.init(id: "conversion.\(conversion)", label: conversion.label, help: conversion.help) {
            try conversion.apply(to: $0)
        }
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
    static let format: [[TextOperation]] = [
        [
            TextOperation(id: "format.json", label: "Format JSON",
                          help: "Pretty-print JSON, preserving key order") { try Formatter.json($0) },
            TextOperation(id: "format.jsonSorted", label: "Format JSON (Sort Keys)",
                          help: "Pretty-print JSON with every object's keys sorted") { try Formatter.json($0, sortKeys: true) },
            TextOperation(id: "format.jsonMinified", label: "Minify JSON",
                          help: "Strip all whitespace outside strings") { try Formatter.minifiedJSON($0) },
        ],
        [
            TextOperation(id: "format.xml", label: "Format XML",
                          help: "Pretty-print XML, preserving attribute order") { try Formatter.xml($0) },
            TextOperation(id: "format.xmlSorted", label: "Format XML (Sort Attributes)",
                          help: "Pretty-print XML with every element's attributes sorted") { try Formatter.xml($0, sortAttributes: true) },
            TextOperation(id: "format.xmlMinified", label: "Minify XML",
                          help: "Strip inter-element whitespace, producing one line") { try Formatter.minifiedXML($0) },
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
        [TextOperation(Conversion.base64Decode), TextOperation(Transform.base64Encode),
         TextOperation(Conversion.hexDecode), TextOperation(Transform.hexEncode)],
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
        conversions(.jwtDecode, .timestampToDate, .dateToTimestamp),
    ]

    /// Flattened union, for the tests that check nothing was implemented and
    /// then forgotten on the way to a menu.
    static let all: [TextOperation] =
        format.flatMap { $0 } + text.flatMap { $0 } + convert.flatMap { $0 } + hashes + decoders.flatMap { $0 }

    private static func operations(_ transforms: Transform...) -> [TextOperation] {
        transforms.map { TextOperation($0) }
    }

    private static func conversions(_ conversions: Conversion...) -> [TextOperation] {
        conversions.map { TextOperation($0) }
    }
}
