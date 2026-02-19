// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hermes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hermes",
            path: "Sources/Hermes",
            resources: [
                .copy("Config/commands.json")
            ]
        )
    ]
)
