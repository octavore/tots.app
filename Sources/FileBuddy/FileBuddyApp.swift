import SwiftUI

@main
struct FileBuddyApp: App {
  var body: some Scene {
    WindowGroup("FileBuddy") {
      ContentView()
        .frame(minWidth: 800, minHeight: 520)
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)
  }
}
