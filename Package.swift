// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    // Require `any` for existential types.
    .enableUpcomingFeature("ExistentialAny")
]

let package = Package(
    name: "swift-openapi-hummingbird",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
    ],
    products: [
        .library(name: "OpenAPIHummingbird", targets: ["OpenAPIHummingbird"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "0.1.3")),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OpenAPIHummingbird",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OpenAPIHummingbirdTests",
            dependencies: [
                "OpenAPIHummingbird",
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
