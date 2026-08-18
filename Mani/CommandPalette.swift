import SwiftUI

/// Searchable list of the commands that apply to the current text, shown as an
/// overlay. Arrows or ⌃N/⌃P move the highlight, Page Up and Page Down move by
/// eight, Home and End jump to the ends, Return runs the highlighted command
/// and Escape closes. Typing keeps narrowing the list the whole time, because
/// the field never gives up focus.
struct CommandPalette: View {
    let commands: [TextOperation]
    let onRun: (TextOperation) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var matches: [TextOperation] = []
    @State private var selection = 0

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if matches.isEmpty {
                Text("No matching commands")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            } else {
                list
            }
        }
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        .shadow(radius: 16)
        .accessibilityAddTraits(.isModal)
        .onAppear { matches = commands }
        .onChange(of: query) {
            matches = CommandSearch.matches(commands, query: query)
            selection = 0
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            PaletteSearchField(
                text: $query,
                onMove: move(by:),
                onJump: move(to:),
                onSubmit: runSelected,
                onCancel: onDismiss
            )
            .frame(height: 24)
        }
        .padding(10)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { index, command in
                        row(command, isSelected: index == selection)
                            .id(index)
                            .onTapGesture {
                                selection = index
                                runSelected()
                            }
                    }
                }
            }
            .frame(maxHeight: 280)
            .onChange(of: selection) { proxy.scrollTo(selection) }
        }
    }

    private func row(_ command: TextOperation, isSelected: Bool) -> some View {
        HStack {
            Text(command.label)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
        .help(command.help)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Steps of one wrap, the way every palette does; larger jumps clamp.
    private func move(by delta: Int) {
        guard !matches.isEmpty else { return }
        selection = abs(delta) == 1
            ? (selection + delta + matches.count) % matches.count
            : min(max(selection + delta, 0), matches.count - 1)
    }

    private func move(to index: Int) {
        guard !matches.isEmpty else { return }
        selection = min(max(index, 0), matches.count - 1)
    }

    private func runSelected() {
        guard matches.indices.contains(selection) else { return }
        onRun(matches[selection])
        onDismiss()
    }
}
