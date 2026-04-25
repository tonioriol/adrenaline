// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cocaine",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Cocaine", targets: ["Cocaine"]),
        .executable(name: "CocaineHelper", targets: ["CocaineHelper"]),
        .library(name: "CocaineCore", targets: ["CocaineCore"]),
    ],
    targets: [
        .target(
            name: "CocaineCore",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "Cocaine",
            dependencies: ["CocaineCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "CocaineHelper",
            dependencies: ["CocaineCore"],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("IOKit"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/CocaineHelper/Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__launchd_plist",
                    "-Xlinker", "Resources/CocaineHelper/launchd.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "CocaineCoreTests",
            dependencies: ["CocaineCore"]
        ),
    ]
)
