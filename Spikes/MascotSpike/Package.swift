// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MascotSpike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MascotSpike",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
