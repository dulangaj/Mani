import SwiftUI

/// The find machinery on one line: field, mode, options, count, and the
/// stepper, with a slot for whatever a feature does to the hits. The strip bar
/// puts `Strip`/`Strip All` in the slot; a replace bar would put its own field
/// and buttons there. The bar owns the wiring that every such feature needs —
/// refresh on each keystroke and document edit, highlight every hit, clear the
/// highlight on the way out — so a new feature writes none of it.
struct FindBar<Actions: View>: View {
    let text: String
    let editor: EditorController
    @Bindable var controller: FindController
    /// The field's placeholder, which is the one word of intent the bar shows:
    /// "Strip" reads as a promise about what ⏎ will do.
    let prompt: String
    /// ⏎ in the field. The bar cannot know: strip removes the current hit, a
    /// replace bar would rewrite it.
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    @ViewBuilder var actions: Actions

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(prompt, text: $controller.pattern.text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(onSubmit)
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
            actions
            Button(action: onDismiss) {
                Label("Close", systemImage: "xmark").labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("Close the find bar (⎋)")
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
}
