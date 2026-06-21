// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tots",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tots",
            path: "Sources/Tots"
        )
    ]
)
