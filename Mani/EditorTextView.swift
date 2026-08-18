import SwiftUI
import AppKit

/// Bridges the transform menus to the hosted NSTextView so every change flows
/// through the view's own undo machinery.
@MainActor
@Observable
final class EditorController {
    weak var textView: NSTextView?

    /// The current selection, or nil when nothing is selected. Operations run
    /// on the selection when there is one, so this is what content detection
    /// has to judge — a base64 field inside a JSON document is base64.
    private(set) var selectedText: String?

    /// Returns focus to the document, which an overlay takes away.
    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    func selectionChanged() {
        guard let textView else { return }
        let range = textView.selectedRange()
        selectedText = range.length > 0
            ? (textView.string as NSString).substring(with: range)
            : nil
    }

    /// Applies `body` to the selection, or the whole document when nothing is
    /// selected, then selects the replaced range so the change is visible.
    func apply(_ actionName: String, _ body: (String) throws -> String) rethrows {
        guard let textView else { return }
        let storage = textView.string as NSString
        let selected = textView.selectedRange()
        let range = selected.length > 0 ? selected : NSRange(location: 0, length: storage.length)
        let input = storage.substring(with: range)
        let output = try body(input)
        guard output != input,
              textView.shouldChangeText(in: range, replacementString: output) else { return }
        textView.textStorage?.replaceCharacters(in: range, with: output)
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
        textView.setSelectedRange(NSRange(location: range.location, length: (output as NSString).length))
    }

    /// Async variant for transforms that take time. The buffer stays editable
    /// while `body` runs; the result is dropped if the source text changed.
    func apply(_ actionName: String, _ body: (String) async throws -> String) async throws {
        guard let textView else { return }
        let storage = textView.string as NSString
        let selected = textView.selectedRange()
        let range = selected.length > 0 ? selected : NSRange(location: 0, length: storage.length)
        let input = storage.substring(with: range)
        let output = try await body(input)
        let current = textView.string as NSString
        guard NSMaxRange(range) <= current.length, current.substring(with: range) == input else {
            throw FormatError(message: "The text changed while organizing; result discarded.")
        }
        guard output != input,
              textView.shouldChangeText(in: range, replacementString: output) else { return }
        textView.textStorage?.replaceCharacters(in: range, with: output)
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
        textView.setSelectedRange(NSRange(location: range.location, length: (output as NSString).length))
    }

    /// Applies every replacement, as one undo step. Each range carries its own
    /// string, so strip (every string empty) and a future replace (each string
    /// from its own match) are the same call. The ranges must be disjoint; they
    /// are applied back to front so the earlier ones stay valid as the text
    /// changes length under them.
    func replace(_ replacements: [(range: NSRange, string: String)], actionName: String) {
        guard let textView, !replacements.isEmpty else { return }
        let ordered = replacements.sorted { $0.range.location < $1.range.location }
        guard textView.shouldChangeText(inRanges: ordered.map { NSValue(range: $0.range) },
                                        replacementStrings: ordered.map { $0.string }) else { return }
        for (range, string) in ordered.reversed() {
            textView.textStorage?.replaceCharacters(in: range, with: string)
        }
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
    }

    /// Scrolls a range into view without selecting it, which would both paint
    /// over the highlight and quietly narrow every menu operation to it.
    func reveal(_ range: NSRange) {
        textView?.scrollRangeToVisible(range)
    }

    /// A pattern with thousands of hits shows the first few hundred, plus the
    /// current one wherever it sits; the bar still counts them all.
    private static let highlightCap = 500

    /// Paints every match, as a TextKit 2 rendering attribute rather than a real
    /// one, so the document and its undo stack stay untouched.
    ///
    /// `current` is painted last, and in red, so the hit the find bar is
    /// sitting on reads differently from the rest of them.
    func highlight(_ ranges: [NSRange], current: NSRange? = nil) {
        guard let textView, let layout = textView.textLayoutManager,
              let content = layout.textContentManager else { return }
        for key in [NSAttributedString.Key.backgroundColor, .foregroundColor] {
            layout.removeRenderingAttribute(key, for: content.documentRange)
        }
        // Invalidating discards whatever is set at the time, so the clear has
        // to happen before the new highlight goes on, not after.
        layout.invalidateRenderingAttributes(for: content.documentRange)
        func paint(_ range: NSRange, _ background: NSColor, _ foreground: NSColor) {
            guard let textRange = content.textRange(range) else { return }
            layout.addRenderingAttribute(.backgroundColor, value: background, for: textRange)
            layout.addRenderingAttribute(.foregroundColor, value: foreground, for: textRange)
        }
        // The system find colour, specified to be read with black text: a
        // translucent wash is invisible against monospaced text.
        for range in ranges.prefix(Self.highlightCap) {
            paint(range, .findHighlightColor, .black)
        }
        if let current {
            paint(current, .systemRed, .white)
        }
        // Neither removing nor adding a rendering attribute repaints fragments
        // already on screen — without this, a new highlight only shows once
        // something else forces a redraw, such as stepping scrolling the view.
        textView.needsDisplay = true
    }
}

/// Plain-text NSTextView host: monospaced, no smart substitutions, with the
/// system find bar and typing undo — none of which SwiftUI's TextEditor
/// offers on macOS 15.
struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.writingToolsBehavior = .complete
        textView.textContainerInset = NSSize(width: 5, height: 8)
        textView.delegate = context.coordinator
        textView.string = text
        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              textView.string != text else { return }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        init(_ parent: EditorTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.controller.selectionChanged()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller.selectionChanged()
        }
    }
}

private extension NSTextContentManager {
    /// TextKit 2 addresses text by opaque locations; everything else here, and
    /// every transform, speaks `NSRange`.
    func textRange(_ range: NSRange) -> NSTextRange? {
        guard let start = location(documentRange.location, offsetBy: range.location),
              let end = location(start, offsetBy: range.length) else { return nil }
        return NSTextRange(location: start, end: end)
    }
}
