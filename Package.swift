// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GrowBox",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "GrowBox", path: "Sources/GrowBox")
    ]
)
