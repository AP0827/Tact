// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TactApple",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.executable(name: "TactMac", targets: ["TactApple"])],
    dependencies: [
        .package(path: "../../core/TactCore")
    ],
    targets: [
        .executableTarget(name: "TactApple", dependencies: [.product(name: "TactCore", package: "TactCore")])
    ]
)
