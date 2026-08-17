import SwiftUI

struct ContentView: View {
    @State private var text = ScratchpadFile.load()
    @State private var formatError: String?
    @State private var editor = EditorController()
    @State private var didJustCopy = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var isOrganizing = false

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
                Button("Format JSON") { run("Format JSON") { try Formatter.json($0) } }
                Button("Format JSON (Sort Keys)") { run("Format JSON (Sort Keys)") { try Formatter.json($0, sortKeys: true) } }
                Button("Minify JSON") { run("Minify JSON", Formatter.minifiedJSON) }
                Divider()
                Button("Format XML") { run("Format XML") { try Formatter.xml($0) } }
                Button("Format XML (Sort Attributes)") { run("Format XML (Sort Attributes)") { try Formatter.xml($0, sortAttributes: true) } }
                Button("Minify XML") { run("Minify XML", Formatter.minifiedXML) }
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
            organizeButton
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

    private var organizeButton: some View {
        Button {
            organize()
        } label: {
            if isOrganizing {
                ProgressView().controlSize(.small)
            } else {
                Label("Organize", systemImage: "sparkles")
            }
        }
        .disabled(isOrganizing)
        .help("Rewrite the text, or the selection, as Markdown with the on-device Apple Intelligence model")
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

    private func organize() {
        isOrganizing = true
        Task { @MainActor in
            do {
                try await editor.apply("Organize", Organizer.markdown)
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
