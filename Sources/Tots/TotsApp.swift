import SwiftUI

@main
struct TotsApp: App {
  var body: some Scene {
    WindowGroup("Tots") {
      ContentView()
        .frame(minWidth: 800, minHeight: 520)
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)
  }
}
