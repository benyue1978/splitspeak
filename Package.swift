// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "splitspeak",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SCTCore", targets: ["SCTCore"])
    ],
    targets: [
        .target(name: "SCTCore", path: "Modules/SCTCore/Sources"),
        .testTarget(name: "SCTCoreTests", dependencies: ["SCTCore"], path: "Modules/SCTCore/Tests")
    ]
)
