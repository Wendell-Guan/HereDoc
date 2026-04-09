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
        .library(name: "HereDocMCP", targets: ["HereDocMCP"]),
    ],
    dependencies: [
        .package(path: "refs/GRDB.swift"),
        .package(path: "refs/mcp-swift-sdk"),
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
        .target(
            name: "HereDocMCP",
            dependencies: [
                "HereDocModels",
                .product(name: "MCP", package: "mcp-swift-sdk"),
            ]
        ),
        .testTarget(
            name: "HereDocTests",
            dependencies: [
                "HereDocSearch",
                "HereDocAI",
                "HereDocMCP",
                "HereDocStorage",
            ]
        ),
    ]
)
