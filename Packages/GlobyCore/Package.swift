// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlobyCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlobyCore", targets: ["GlobyCore"])
    ],
    targets: [
        .target(
            name: "GlobyCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GlobyCoreTests",
            dependencies: ["GlobyCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
