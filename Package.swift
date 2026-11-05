// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenubarKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MenubarKit", targets: ["MenubarKit"]),
        .executable(name: "make-tray-glyph", targets: ["make-tray-glyph"]),
    ],
    targets: [
        .target(
            name: "MenubarKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "make-tray-glyph",
            dependencies: ["MenubarKit"],
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
