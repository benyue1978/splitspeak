// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "splitspeak",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SCTCore", targets: ["SCTCore"]),
        .library(name: "SCTAudio", targets: ["SCTAudio"]),
        .library(name: "SCTConversation", targets: ["SCTConversation"]),
        .library(name: "SCTPipeline", targets: ["SCTPipeline"])
    ],
    targets: [
        .target(name: "SCTCore", path: "Modules/SCTCore/Sources"),
        .testTarget(name: "SCTCoreTests", dependencies: ["SCTCore"], path: "Modules/SCTCore/Tests"),
        .target(name: "SCTAudio", dependencies: ["SCTCore"], path: "Modules/SCTAudio/Sources"),
        .testTarget(name: "SCTAudioTests", dependencies: ["SCTAudio"], path: "Modules/SCTAudio/Tests"),
        .target(name: "SCTConversation", dependencies: ["SCTCore"], path: "Modules/SCTConversation/Sources"),
        .testTarget(name: "SCTConversationTests", dependencies: ["SCTConversation"], path: "Modules/SCTConversation/Tests"),
        .target(name: "SCTPipeline", dependencies: ["SCTCore"], path: "Modules/SCTPipeline/Sources"),
        .testTarget(name: "SCTPipelineTests", dependencies: ["SCTPipeline"], path: "Modules/SCTPipeline/Tests")
    ]
)
