// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Video2MP3",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Video2MP3Core",
            targets: ["Video2MP3Core"]
        ),
        .executable(
            name: "Video2MP3",
            targets: ["Video2MP3App"]
        )
    ],
    targets: [
        .target(
            name: "Video2MP3Core"
        ),
        .executableTarget(
            name: "Video2MP3App",
            dependencies: ["Video2MP3Core"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "Video2MP3CoreTests",
            dependencies: ["Video2MP3Core"]
        )
    ]
)
