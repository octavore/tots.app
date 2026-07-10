import SwiftUI

@main
struct TotsApp: App {
  var body: some Scene {
    WindowGroup("Tots") {
      ContentView()
    }
    .windowStyle(.titleBar)
    .windowToolbarStyle(.unified)
  }
}
