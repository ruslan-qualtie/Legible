// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "Legible",
    platforms: [
        .macOS(.v11)
        ],
    products: [
        .library(
            name: "Legible",
            targets: ["Legible"]),
    ],
    dependencies: [
        .package(
            name: "Quick",
            url: "https://github.com/Quick/Quick.git",
            from: "4.0.0"
        ),
        .package(
            name: "Nimble",
            url: "https://github.com/Quick/Nimble.git",
            from: "9.1.0"
        ),
    ],
    targets: [
        .target(
            name: "Legible",
            dependencies: [
                "Quick",
                "Nimble"
            ],
            path: "Legible"
        ),
        .testTarget(
            name: "Legible_Tests",
            dependencies: [
                "Legible",
                "Quick",
                "Nimble"
            ],
            path: "Example/Tests",
            exclude: ["Info.plist"],
            resources: [
                .copy("AvatarView.png"),
                .copy("AvatarView-1.png"),
                .copy("AvatarView-2.png"),
                .copy("HelloWorld.png"),
                .copy("HDivider.png"),
                .copy("Snapshots"),
                .process("Specs.xctestplan"),
                .process("Performance.xctestplan"),
                .copy("Info.plist")
            ]
        )
    ]
)
