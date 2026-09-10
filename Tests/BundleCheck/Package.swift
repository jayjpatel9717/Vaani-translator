// swift-tools-version: 5.9
// Regression check for the KeyboardShortcuts resource-bundle crash. See run.sh.
import PackageDescription

let package = Package(
    name: "BundleCheck",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../Vendor/KeyboardShortcuts")
    ],
    targets: [
        .executableTarget(name: "BundleCheck", dependencies: ["KeyboardShortcuts"])
    ]
)
