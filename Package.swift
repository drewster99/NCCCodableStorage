// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NCCCodableStorage",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "NCCCodableStorage",
            targets: ["NCCCodableStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/drewster99/NCCCoding.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "NCCCodableStorage",
            dependencies: ["NCCCoding"]),
        .testTarget(
            name: "NCCCodableStorageTests",
            dependencies: ["NCCCodableStorage"]),
    ]
)
