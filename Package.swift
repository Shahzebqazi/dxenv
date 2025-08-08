// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dxenv",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "dxenv", targets: ["dxenv"]),
        .library(name: "dxenvCore", targets: ["dxenvCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "dxenv",
            dependencies: [
                "dxenvCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "dxenvCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "dxenvTests",
            dependencies: ["dxenvCore"]
        )
    ]
)
