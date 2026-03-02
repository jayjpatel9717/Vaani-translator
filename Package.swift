// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SaarasTranslator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SaarasTranslator",
            targets: ["SaarasTranslator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.14.0")
    ],
    targets: [
        .executableTarget(
            name: "SaarasTranslator",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources"
        )
    ]
)
