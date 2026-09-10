// swift-tools-version:5.7
// Vendored from https://github.com/sindresorhus/KeyboardShortcuts v1.14.0 (MIT).
// Local copy exists only to patch the resource-bundle lookup in Utilities.swift;
// SwiftPM's generated Bundle.module does not look in <App>.app/Contents/Resources.
import PackageDescription

let package = Package(
	name: "KeyboardShortcuts",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v10_13)
	],
	products: [
		.library(
			name: "KeyboardShortcuts",
			targets: [
				"KeyboardShortcuts"
			]
		)
	],
	targets: [
		.target(
			name: "KeyboardShortcuts"
		)
	]
)
