import SwiftUI
import AppKit

/// The palette's search field.
///
/// SwiftUI's `TextField` cannot drive the list: its field editor swallows the
/// arrow keys as cursor motion before `onKeyPress` ever sees them. AppKit's own
/// answer to this is `control(_:textView:doCommandBy:)`, which hands the field
/// the selector the key resolved to, so we intercept motion there and let
/// everything else stay ordinary typing.
///
/// Working in selectors rather than keys also buys the Emacs bindings for free:
/// macOS already maps ⌃N and ⌃P onto `moveDown:` and `moveUp:`.
struct PaletteSearchField: NSViewRepresentable {
    @Binding var text: String
    let onMove: (Int) -> Void
    let onJump: (Int) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Search commands"
        field.font = .systemFont(ofSize: NSFont.systemFontSize + 4)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.sendsActionOnEndEditing = false
        field.stringValue = text
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaletteSearchField
        init(_ parent: PaletteSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)): parent.onMove(1)
            case #selector(NSResponder.moveUp(_:)): parent.onMove(-1)
            case #selector(NSResponder.pageDown(_:)), #selector(NSResponder.scrollPageDown(_:)):
                parent.onMove(8)
            case #selector(NSResponder.pageUp(_:)), #selector(NSResponder.scrollPageUp(_:)):
                parent.onMove(-8)
            case #selector(NSResponder.moveToBeginningOfDocument(_:)),
                 #selector(NSResponder.scrollToBeginningOfDocument(_:)):
                parent.onJump(.min)
            case #selector(NSResponder.moveToEndOfDocument(_:)),
                 #selector(NSResponder.scrollToEndOfDocument(_:)):
                parent.onJump(.max)
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)): parent.onCancel()
            default: return false
            }
            return true
        }
    }
}
