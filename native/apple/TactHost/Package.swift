// swift-tools-version: 6.0
import PackageDescription
let package=Package(name:"TactHost",platforms:[.macOS(.v14)],dependencies:[.package(path:"../../core/TactCore")],targets:[.executableTarget(name:"TactHost",dependencies:[.product(name:"TactCore",package:"TactCore")])])
