// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Insomnia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Insomnia", targets: ["Insomnia"]),
        .executable(name: "InsomniaHelper", targets: ["InsomniaHelper"]),
        .library(name: "InsomniaCore", targets: ["InsomniaCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "InsomniaCore",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "Insomnia",
            dependencies: [
                "InsomniaCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "InsomniaHelper",
            dependencies: ["InsomniaCore"],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/InsomniaHelper/Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "Resources/InsomniaHelper/launchd.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "InsomniaCoreTests",
            dependencies: ["InsomniaCore"]
        ),
    ]
)
