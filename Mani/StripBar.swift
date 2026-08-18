import SwiftUI
import AppKit

/// What the strip bar is looking for, and where in the list of hits it is
/// sitting. It holds no text of its own: `refresh(in:)` is called whenever the
/// document or the pattern changes.
@MainActor
@Observable
final class StripController {
    var pattern = StripPattern()
    private(set) var matches: [NSRange] = []
    private(set) var isPatternValid = true
    private(set) var current = 0

    var status: String {
        if pattern.text.isEmpty { return "" }
        if !isPatternValid { return "Bad pattern" }
        return matches.isEmpty ? "No matches" : "\(current + 1) of \(matches.count)"
    }

    /// The index is kept rather than reset, so stripping one hit leaves the bar
    /// pointing at the one that took its place.
    func refresh(in text: String) {
        do {
            matches = try pattern.ranges(in: text)
            isPatternValid = true
        } catch {
            matches = []
            isPatternValid = false
        }
        current = min(current, max(matches.count - 1, 0))
    }

    var currentMatch: NSRange? {
        matches.indices.contains(current) ? matches[current] : nil
    }

    func step(_ delta: Int) -> NSRange? {
        guard !matches.isEmpty else { return nil }
        // `%` keeps the sign of its left operand, so the delta is folded into
        // range before the wrap, or a jump wider than the list goes negative.
        current = (current + delta % matches.count + matches.count) % matches.count
        return matches[current]
    }
}

/// Find and strip, on one line above the bottom bar. Every hit is highlighted
/// as you type, and the count tells you how many there are before you commit to
/// anything; ⏎ strips the one you are on and lands on the next, `Strip All`
/// takes the lot as a single undo step.
struct StripBar: View {
    let text: String
    let editor: EditorController
    @Bindable var controller: StripController
    let onStrip: ([NSRange]) -> Void
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Strip", text: $controller.pattern.text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(stripCurrent)
                .frame(minWidth: 140, idealWidth: 200, maxWidth: 260)
            Picker("Mode", selection: $controller.pattern.mode) {
                ForEach(MatchMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Toggle("Aa", isOn: $controller.pattern.isCaseSensitive)
                .toggleStyle(.button)
                .help("Match case")
            Toggle("Word", isOn: $controller.pattern.isWholeWord)
                .toggleStyle(.button)
                .help("Match whole words only")
            Text(controller.status)
                .font(.callout)
                .foregroundStyle(controller.isPatternValid ? Color.secondary : Color.red)
                .monospacedDigit()
            Spacer(minLength: 0)
            stepper
            Button("Strip", action: stripCurrent)
                .disabled(controller.currentMatch == nil)
                .help("Remove this match (⏎)")
            Button("Strip All") { onStrip(controller.matches) }
                .buttonStyle(.borderedProminent)
                .disabled(controller.matches.isEmpty)
                .help("Remove every match, as one undo step")
            Button(action: onDismiss) {
                Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("Close the strip bar (⎋)")
        }
        .padding(8)
        .onAppear {
            refresh()
            isFocused = true
        }
        .onChange(of: controller.pattern) { refresh() }
        .onChange(of: text) { refresh() }
        .onDisappear { editor.highlight([]) }
        .onExitCommand(perform: onDismiss)
    }

    private var stepper: some View {
        ControlGroup {
            Button { move(-1) } label: { Image(systemName: "chevron.up") }
                .help("Previous match")
            Button { move(1) } label: { Image(systemName: "chevron.down") }
                .help("Next match")
        }
        .fixedSize()
        .disabled(controller.matches.isEmpty)
    }

    private func refresh() {
        controller.refresh(in: text)
        editor.highlight(controller.matches, current: controller.currentMatch)
    }

    private func move(_ delta: Int) {
        guard let range = controller.step(delta) else { return }
        editor.highlight(controller.matches, current: range)
        editor.reveal(range)
    }

    private func stripCurrent() {
        guard let range = controller.currentMatch else { return }
        onStrip([range])
    }
}
