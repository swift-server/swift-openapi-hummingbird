// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-openapi-hummingbird",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9),
    ],
    products: [
        .library(name: "HummingbirdOpenAPI", targets: ["HummingbirdOpenAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", branch: "main"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HummingbirdOpenAPI",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
        .testTarget(
            name: "HummingbirdOpenAPITests",
            dependencies: [
                "HummingbirdOpenAPI",
                .product(name: "HummingbirdXCT", package: "hummingbird"),
            ]
        ),
    ]
)
