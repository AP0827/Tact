// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TactCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TactCore", targets: ["TactCore"])
    ],
    targets: [
        .target(name: "TactCore")
    ]
)
