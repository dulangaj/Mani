import SwiftUI

struct ContentView: View {
    @State private var text = ScratchpadFile.load()
    @State private var formatError: String?
    @State private var editor = EditorController()
    @State private var didJustCopy = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            EditorTextView(text: $text, controller: editor)
            if let formatError {
                errorBanner(formatError)
            }
            Divider()
            bottomBar
        }
        .onChange(of: text) { formatError = nil }
        .task(id: text) {
            try? await Task.sleep(for: .seconds(1))
            ScratchpadFile.save(text)
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            statusText
            Spacer()
            Menu("Format") {
                Button("Format JSON") { run("Format JSON", Formatter.json) }
                Button("Minify JSON") { run("Minify JSON", Formatter.minifiedJSON) }
                Divider()
                Button("Format XML") { run("Format XML", Formatter.xml) }
            }
            .fixedSize()
            .help("Pretty-print the text, or the selection if there is one")
            Menu("Replace") {
                ForEach(Array(Transform.groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 { Divider() }
                    ForEach(group) { transform in
                        Button(transform.label) { run(transform.label) { transform.apply(to: $0) } }
                            .help(transform.help)
                    }
                }
            }
            .fixedSize()
            .help("Apply a cleanup to the text, or the selection if there is one")
            copyButton
        }
        .disabled(text.isEmpty)
        .padding(8)
    }

    private var statusText: some View {
        let lines = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        return Text("\(text.count.formatted()) \(text.count == 1 ? "character" : "characters")"
            + " · \(lines.formatted()) \(lines == 1 ? "line" : "lines")")
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()
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

    private func run(_ name: String, _ body: (String) throws -> String) {
        do {
            try editor.apply(name, body)
            formatError = nil
        } catch {
            formatError = error.localizedDescription
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
