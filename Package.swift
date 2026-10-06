// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Speeder",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SpeederCore", targets: ["SpeederCore"]),
        .library(name: "SpeederCapture", targets: ["SpeederCapture"]),
        .executable(name: "Speeder", targets: ["Speeder"]),
    ],
    targets: [
        // Metrics: pure Foundation, no UI, no event taps. Fully unit tested.
        .target(
            name: "SpeederCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Keystroke capture: a `CGEventTap` session tap, which requires the app to
        // be trusted for Accessibility.
        .target(
            name: "SpeederCapture",
            dependencies: ["SpeederCore", "SpeederShims"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // C shim for the few CoreFoundation calls Swift cannot reliably see.
        .target(name: "SpeederShims"),
        // Menu bar UI.
        .executableTarget(
            name: "Speeder",
            dependencies: ["SpeederCore", "SpeederCapture"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpeederCaptureTests",
            dependencies: ["SpeederCapture", "SpeederCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpeederCoreTests",
            dependencies: ["SpeederCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
