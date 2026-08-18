//
//  ManiApp.swift
//  Mani
//

import SwiftUI

@main
struct ManiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 720, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .textEditing) {
                SearchCommandsButton()
            }
        }
    }
}

/// Lives in the menu bar rather than on the toolbar button so ⇧⌘P travels the
/// standard key-equivalent path: discoverable, listed in Help search, and
/// independent of whether the bottom bar happens to be disabled.
private struct SearchCommandsButton: View {
    @FocusedValue(\.isSearching) private var isSearching

    var body: some View {
        Button("Search Commands…") { isSearching?.wrappedValue.toggle() }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(isSearching == nil)
    }
}

/// Carries the front window's palette state up to the menu bar.
extension FocusedValues {
    @Entry var isSearching: Binding<Bool>?
}
