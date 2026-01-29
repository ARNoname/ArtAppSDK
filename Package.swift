// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArtAppSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "ArtAppSDK",
            targets: ["ArtAppSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", from: "13.5.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ArtAppSDK",
            dependencies: [
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package")
            ]
        ),

    ]
)

