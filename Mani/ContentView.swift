import SwiftUI

struct ContentView: View {
    @State private var text = ScratchpadFile.load()
    @State private var formatError: String?
    @State private var editor = EditorController()
    @State private var didJustCopy = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var isOrganizing = false
    @State private var isSearching = false
    @State private var isStripping = false
    @State private var strip = FindController()

    private static let organizePrefix = "organize."

    /// Sentinel palette entries for Organize, which runs async and so cannot be
    /// a plain `TextOperation`; `run(_:)` special-cases the id prefix.
    private static let organizeCommands: [TextOperation] = OrganizeTarget.allCases.map { target in
        TextOperation(id: organizePrefix + target.rawValue,
                      label: "Organize as \(target.label)", help: target.help) { $0 }
    }

    /// The same sentinel trick, for a command that opens a bar instead of
    /// transforming anything itself.
    private static let stripCommand = TextOperation(
        id: "strip", label: "Strip Text\u{2026}",
        help: "Find every occurrence of a string or pattern and remove it") { $0 }

    /// Cached, because every menu item and every palette row asks whether it
    /// applies: as a computed property this ran detection some forty-five times
    /// per keystroke. It is recomputed only when the text or the selection
    /// actually changes.
    @State private var kind: ContentKind?

    var body: some View {
        VStack(spacing: 0) {
            EditorTextView(text: $text, controller: editor)
            if isStripping {
                Divider()
                StripBar(text: text, editor: editor, controller: strip,
                         onStrip: stripRanges, onDismiss: closeStrip)
            }
            if let formatError {
                errorBanner(formatError)
            }
            Divider()
            bottomBar
        }
        .onChange(of: text) {
            formatError = nil
            detectKind()
        }
        .onChange(of: editor.selectedText) { detectKind() }
        .onAppear(perform: detectKind)
        .focusedSceneValue(\.isSearching, $isSearching)
        .overlay {
            if isSearching {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.12)
                        .onTapGesture(perform: dismissPalette)
                    CommandPalette(
                        commands: availableCommands,
                        onRun: run,
                        onDismiss: dismissPalette
                    )
                    .padding(.top, 24)
                }
            }
        }
        .task(id: text) {
            try? await Task.sleep(for: .seconds(1))
            ScratchpadFile.save(text)
        }
        .frame(minWidth: 560, minHeight: 320)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if isOrganizing {
                ProgressView().controlSize(.small)
            }
            statusText
            Spacer()
            Button {
                isSearching.toggle()
            } label: {
                Label("Search Commands", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .help("Search all commands (⇧⌘P)")
            editingControls
        }
        .padding(8)
    }

    /// Everything here needs text to work on; the palette does not, so it sits
    /// outside this group and stays reachable with an empty buffer.
    @ViewBuilder
    private var editingControls: some View {
        Group {
            stripButton
            Menu("Format") { items(Menus.format) }
                .fixedSize()
                .help("Pretty-print structured data, or the selection if there is one")
            Menu("Text") { items(Menus.text) }
                .fixedSize()
                .help("Reshape the text, or the selection if there is one")
            Menu("Convert") {
                items(Menus.convert)
                Divider()
                Menu("Hash") {
                    ForEach(Menus.hashes) { operation in
                        Button(operation.label) { run(operation) }
                            .help(operation.help)
                    }
                }
                Divider()
                items(Menus.decoders)
                Menu("Timestamp") { items(Menus.timestamps) }
            }
            .fixedSize()
            .help("Re-encode the text, or the selection if there is one")
            organizeMenu
            copyButton
        }
        .disabled(text.isEmpty)
    }

    /// Renders one menu's groups, separated by dividers.
    @ViewBuilder
    private func items(_ groups: [[TextOperation]]) -> some View {
        ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
            if index > 0 { Divider() }
            ForEach(group) { operation in
                Button(operation.label) { run(operation) }
                    .help(operation.help)
                    .disabled(!operation.isEnabled(for: kind))
            }
        }
    }

    private var statusText: some View {
        Text(TextStats.summary(for: text, kind: kind))
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var stripButton: some View {
        Button(action: toggleStrip) {
            Label("Strip", systemImage: "scissors").labelStyle(.iconOnly)
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .help("Find and strip a string or pattern (\u{21E7}\u{2318}S)")
    }

    private var copyButton: some View {
        Button {
            copyAll()
        } label: {
            Label(didJustCopy ? "Copied" : "Copy", systemImage: didJustCopy ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .help("Copy all text to the clipboard (⇧⌘C)")
    }

    /// A `Menu` cannot swap its label for a spinner the way the old button did,
    /// so the running indicator lives in the bottom bar instead.
    private var organizeMenu: some View {
        Menu("Organize") {
            ForEach(OrganizeTarget.allCases) { target in
                Button(target.label) { organize(target) }
                    .help(target.help)
            }
        }
        .fixedSize()
        .disabled(isOrganizing)
        .help("Rewrite the text, or the selection, with the on-device Apple Intelligence model")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .lineLimit(2)
            Spacer()
            Button("Dismiss") { formatError = nil }
        }
        .padding(8)
        .background(.yellow.opacity(0.2))
    }

    // MARK: - Actions

    /// Organize is left out while one is already running, since the palette has
    /// no way to show the spinner the button does.
    private var availableCommands: [TextOperation] {
        let commands = Menus.all + [Self.stripCommand] + (isOrganizing ? [] : Self.organizeCommands)
        return commands.filter { $0.isEnabled(for: kind) }
    }

    private func detectKind() {
        kind = ContentKind.detect(editor.selectedText ?? text)
    }

    private func dismissPalette() {
        isSearching = false
        editor.focus()
    }

    private func run(_ operation: TextOperation) {
        if operation.id == Self.stripCommand.id { return openStrip() }
        if let target = Self.organizeTarget(of: operation) { return organize(target) }
        do {
            try editor.apply(operation.label, operation.run)
            formatError = nil
        } catch {
            formatError = error.localizedDescription
        }
    }

    /// The palette's Organize rows carry their target in the id.
    private static func organizeTarget(of operation: TextOperation) -> OrganizeTarget? {
        guard operation.id.hasPrefix(organizePrefix) else { return nil }
        return OrganizeTarget(rawValue: String(operation.id.dropFirst(organizePrefix.count)))
    }

    private func toggleStrip() {
        isStripping ? closeStrip() : openStrip()
    }

    /// Opening on a selection fills the field with it, which is the common case:
    /// you found the thing you want gone, now get rid of all of them.
    private func openStrip() {
        if let selected = editor.selectedText, !selected.contains("\n") {
            strip.pattern.text = selected
            strip.pattern.mode = .plain
        }
        isStripping = true
    }

    private func closeStrip() {
        isStripping = false
        editor.focus()
    }

    private func stripRanges(_ ranges: [NSRange]) {
        editor.replace(ranges.map { ($0, "") }, actionName: "Strip")
    }

    private func organize(_ target: OrganizeTarget) {
        isOrganizing = true
        Task { @MainActor in
            do {
                try await editor.apply("Organize") { try await Organizer.rewrite($0, as: target) }
                formatError = nil
            } catch {
                formatError = error.localizedDescription
            }
            isOrganizing = false
        }
    }

    private func copyAll() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        didJustCopy = true
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            didJustCopy = false
        }
    }
}

#Preview {
    ContentView()
}
