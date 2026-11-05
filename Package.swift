// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenubarKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MenubarKit", targets: ["MenubarKit"])
    ],
    targets: [
        .target(
            name: "MenubarKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MenubarKitTests",
            dependencies: ["MenubarKit"],
            exclude: ["Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
