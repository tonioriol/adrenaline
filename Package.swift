// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Adrenaline",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Adrenaline", targets: ["Adrenaline"]),
        .executable(name: "AdrenalineHelper", targets: ["AdrenalineHelper"]),
        .library(name: "AdrenalineCore", targets: ["AdrenalineCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "AdrenalineCore",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "Adrenaline",
            dependencies: [
                "AdrenalineCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "AdrenalineHelper",
            dependencies: ["AdrenalineCore"],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/AdrenalineHelper/Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "Resources/AdrenalineHelper/launchd.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "AdrenalineCoreTests",
            dependencies: ["AdrenalineCore"]
        ),
    ]
)
