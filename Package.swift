// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "screeny",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "screeny",
            path: "Sources/screeny"
        )
    ]
)
