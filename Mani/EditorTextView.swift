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
