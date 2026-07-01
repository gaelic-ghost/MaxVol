// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MaxVol",
    platforms: [
        .macOS("15.0"),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MaxVol",
            targets: ["MaxVol"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MaxVol",
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK"),
                .define("ACCELERATE_LAPACK_ILP64"),
            ]
        ),
        .testTarget(
            name: "MaxVolTests",
            dependencies: ["MaxVol"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

package.dependencies.append(
    .package(
        url: "https://github.com/apple/swift-configuration",
        from: "1.2.0",
        traits: [.defaults, "Reloading", "YAML", "CommandLineArguments"]
    )
)

for target in package.targets where target.name == "MaxVol" {
    target.dependencies.append(
        .product(name: "Configuration", package: "swift-configuration")
    )
}
