// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CharacterKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "CharacterKit", targets: ["CharacterKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
    ],
    targets: [
        .target(name: "CharacterKit", dependencies: ["Yams"], resources: [.copy("Resources/ose")]),
        .testTarget(name: "CharacterKitTests", dependencies: ["CharacterKit"], resources: [.copy("Fixtures")]),
    ]
)
