import SwiftUI
import AppKit

/// Find and strip, on one line above the bottom bar. Every hit is highlighted
/// as you type, and the count tells you how many there are before you commit to
/// anything; ⏎ strips the one you are on and lands on the next, `Strip All`
/// takes the lot as a single undo step.
///
/// All of that except the two buttons is `FindBar`; this is the one feature
/// built on it so far.
struct StripBar: View {
    let text: String
    /// The highlight and scroll target, handed straight to `FindBar`. Edits go
    /// out through `onStrip` instead, so `ContentView` keeps the one path that
    /// touches the document.
    let editor: EditorController
    let controller: FindController
    let onStrip: ([NSRange]) -> Void
    let onDismiss: () -> Void

    var body: some View {
        FindBar(text: text, editor: editor, controller: controller,
                prompt: "Strip", onSubmit: stripCurrent, onDismiss: onDismiss) {
            Button("Strip", action: stripCurrent)
                .disabled(controller.currentMatch == nil)
                .help("Remove this match (⏎)")
            Button("Strip All") { onStrip(controller.matches) }
                .buttonStyle(.borderedProminent)
                .disabled(controller.matches.isEmpty)
                .help("Remove every match, as one undo step")
        }
    }

    private func stripCurrent() {
        guard let range = controller.currentMatch else { return }
        onStrip([range])
    }
}
