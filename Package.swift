// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RenderMenu",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RenderMenu",
            path: "Sources/RenderMenu"
        )
    ]
)
