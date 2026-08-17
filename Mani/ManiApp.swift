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
        }
    }
}
