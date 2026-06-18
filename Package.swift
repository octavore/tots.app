// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FileBuddy",
            path: "Sources/FileBuddy"
        ),
    ]
)
