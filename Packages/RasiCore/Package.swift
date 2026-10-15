// swift-tools-version: 6.0
import PackageDescription

/// Pure calendar & astronomy logic: no UI, no AppKit, fully unit-tested.
let package = Package(
    name: "RasiCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "RasiCore", targets: ["RasiCore"])],
    targets: [
        .target(name: "RasiCore"),
        .testTarget(name: "RasiCoreTests", dependencies: ["RasiCore"]),
    ]
)
