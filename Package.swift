// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftixSysutils",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Swiftix"),
    ],
    targets: [
        .executableTarget(
            name: "SysutilsPackageBuilder",
            dependencies: [
                .product(name: "Swiftix", package: "Swiftix"),
                .product(name: "SwiftixGo", package: "Swiftix"),
                .product(name: "SwiftixPackages", package: "Swiftix"),
            ]
        ),
        .testTarget(
            name: "SysutilsTests",
            dependencies: [
                .product(name: "Swiftix", package: "Swiftix"),
                .product(name: "SwiftixGo", package: "Swiftix"),
                .product(name: "SwiftixPackages", package: "Swiftix"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
