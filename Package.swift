// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GAMMASetupTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GAMMA Setup Tool", targets: ["GAMMASetupTool"]),
        .executable(name: "gamma-setup-engine", targets: ["GAMMASetupEngine"])
    ],
    targets: [
        .target(
            name: "GAMMASetupCore",
            path: "sources/GAMMASetupCore"
        ),
        .executableTarget(
            name: "GAMMASetupTool",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupTool",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        .executableTarget(
            name: "GAMMASetupEngine",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupEngine",
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        )
    ]
)
