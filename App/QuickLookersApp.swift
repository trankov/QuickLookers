import SwiftUI

@main
struct QuickLookersApp: App {
    var body: some Scene {
        WindowGroup("QuickLookers") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
