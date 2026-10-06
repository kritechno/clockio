// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Clockio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clockio", targets: ["Clockio"]),
        .executable(name: "ClockioCoreChecks", targets: ["ClockioCoreChecks"]),
        .library(name: "ClockioCore", targets: ["ClockioCore"])
    ],
    targets: [
        .target(name: "ClockioCore"),
        .executableTarget(
            name: "Clockio",
            dependencies: ["ClockioCore"]
        ),
        .executableTarget(
            name: "ClockioCoreChecks",
            dependencies: ["ClockioCore"]
        ),
        .testTarget(
            name: "ClockioCoreTests",
            dependencies: ["ClockioCore"]
        )
    ]
)
