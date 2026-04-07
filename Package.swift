// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "splitspeak",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SCTCore", targets: ["SCTCore"]),
        .library(name: "SCTAudio", targets: ["SCTAudio"])
    ],
    targets: [
        .target(name: "SCTCore", path: "Modules/SCTCore/Sources"),
        .testTarget(name: "SCTCoreTests", dependencies: ["SCTCore"], path: "Modules/SCTCore/Tests"),
        .target(name: "SCTAudio", dependencies: ["SCTCore"], path: "Modules/SCTAudio/Sources"),
        .testTarget(name: "SCTAudioTests", dependencies: ["SCTAudio"], path: "Modules/SCTAudio/Tests")
    ]
)
