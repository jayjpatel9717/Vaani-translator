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
        .package(path: "Vendor/KeyboardShortcuts"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2")
    ],
    targets: [
        .executableTarget(
            name: "SaarasTranslator",
            dependencies: [
                "KeyboardShortcuts",
                "KeychainAccess"
            ],
            path: "Sources"
        )
    ]
)
