// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EchWorkersBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "EchWorkersBar",
            path: "Sources/EchWorkersBar"
        )
    ]
)
