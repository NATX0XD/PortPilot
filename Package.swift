// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PortPilot",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PortPilot",
            path: "Sources/PortPilot"
        )
    ]
)
