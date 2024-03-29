// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApolloCancellableHandler",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApolloCancellableHandler",
            targets: ["ApolloCancellableHandler"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApolloCancellableHandler",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloAPI", package: "apollo-ios")
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-strict-concurrency=complete",
                ]),
            ]),
        .testTarget(
            name: "ApolloCancellableHandlerTests",
            dependencies: ["ApolloCancellableHandler"]),
    ]
)
