// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AidenMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AidenShared", targets: ["AidenShared"]),
        .executable(name: "AidenRuntimeAgent", targets: ["AidenRuntimeAgent"]),
        .executable(name: "AidenTrayMac", targets: ["AidenTrayMac"])
    ],
    targets: [
        .target(
            name: "AidenShared",
            path: "Sources/AidenShared"
        ),
        .executableTarget(
            name: "AidenRuntimeAgent",
            dependencies: ["AidenShared"],
            path: "Sources/AidenRuntimeAgent"
        ),
        .executableTarget(
            name: "AidenTrayMac",
            dependencies: ["AidenShared"],
            path: "Sources/AidenTrayMac"
        ),
        .testTarget(
            name: "AidenSharedTests",
            dependencies: ["AidenShared"],
            path: "Tests/AidenSharedTests"
        ),
        .testTarget(
            name: "AidenRuntimeAgentTests",
            dependencies: ["AidenRuntimeAgent", "AidenShared"],
            path: "Tests/AidenRuntimeAgentTests"
        )
    ]
)
