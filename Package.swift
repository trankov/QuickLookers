// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickLookersEngine",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuickLookersEngine", targets: ["QuickLookersEngine"]),
        .library(name: "QuickLookersPreviewKit", targets: ["QuickLookersPreviewKit"]),
        .library(name: "QuickLookersSettingsKit", targets: ["QuickLookersSettingsKit"]),
        .library(name: "QuickLookersImportKit", targets: ["QuickLookersImportKit"]),
    ],
    targets: [
        .target(
            name: "QuickLookersEngine",
            resources: [
                .copy("Resources/shiki-bundle.js"),
                .copy("Resources/grammars"),
                .copy("Resources/themes"),
                .copy("Resources/catalog.json"),
            ]
        ),
        .testTarget(
            name: "QuickLookersEngineTests",
            dependencies: ["QuickLookersEngine"]
        ),
        .target(
            name: "QuickLookersPreviewKit",
            dependencies: ["QuickLookersEngine"]
        ),
        .testTarget(
            name: "QuickLookersPreviewKitTests",
            dependencies: ["QuickLookersPreviewKit"]
        ),
        .target(
            name: "QuickLookersSettingsKit"
        ),
        .testTarget(
            name: "QuickLookersSettingsKitTests",
            dependencies: ["QuickLookersSettingsKit", "QuickLookersEngine"]
        ),
        .systemLibrary(name: "CLibArchive", path: "Sources/CLibArchive"),
        .target(
            name: "QuickLookersImportKit",
            dependencies: ["CLibArchive"]
        ),
        .testTarget(
            name: "QuickLookersImportKitTests",
            dependencies: ["QuickLookersImportKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
