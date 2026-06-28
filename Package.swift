// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickLookersEngine",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuickLookersEngine", targets: ["QuickLookersEngine"]),
    ],
    targets: [
        .target(
            name: "QuickLookersEngine",
            resources: [
                .copy("Resources/shiki-bundle.js"),
                .copy("Resources/grammars"),
                .copy("Resources/themes"),
            ]
        ),
        .testTarget(
            name: "QuickLookersEngineTests",
            dependencies: ["QuickLookersEngine"]
        ),
    ]
)
