// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HereDocKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HereDocModels", targets: ["HereDocModels"]),
        .library(name: "HereDocStorage", targets: ["HereDocStorage"]),
        .library(name: "HereDocSearch", targets: ["HereDocSearch"]),
        .library(name: "HereDocAI", targets: ["HereDocAI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/groue/GRDB.swift",
            revision: "36e30a6f1ef10e4194f6af0cff90888526f0c115"
        ),
    ],
    targets: [
        .target(
            name: "HereDocModels"
        ),
        .target(
            name: "HereDocStorage",
            dependencies: [
                "HereDocModels",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "HereDocSearch",
            dependencies: [
                "HereDocModels",
                "HereDocStorage",
            ]
        ),
        .target(
            name: "HereDocAI",
            dependencies: [
                "HereDocModels",
            ]
        ),
        .testTarget(
            name: "HereDocTests",
            dependencies: [
                "HereDocSearch",
                "HereDocAI",
                "HereDocStorage",
            ]
        ),
    ]
)
