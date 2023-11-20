// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-openapi-hummingbird",
    platforms: [
        .macOS(.v14), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
    ],
    products: [
        .library(name: "OpenAPIHummingbird", targets: ["OpenAPIHummingbird"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", branch: "2.x.x"),
    ],
    targets: [
        .target(
            name: "OpenAPIHummingbird",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
        .testTarget(
            name: "OpenAPIHummingbirdTests",
            dependencies: [
                "OpenAPIHummingbird",
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ]
        ),
    ]
)
