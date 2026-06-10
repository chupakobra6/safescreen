// swift-tools-version: 6.0

import PackageDescription
import Foundation

let developerDirectory = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
    ?? "/Library/Developer/CommandLineTools"
let developerFrameworksDirectory = "\(developerDirectory)/Library/Developer/Frameworks"
let developerLibrariesDirectory = "\(developerDirectory)/Library/Developer/usr/lib"
let hasDeveloperTestingFramework = FileManager.default.fileExists(
    atPath: "\(developerFrameworksDirectory)/Testing.framework"
)
let testingSwiftSettings: [SwiftSetting] = hasDeveloperTestingFramework
    ? [.unsafeFlags(["-F", developerFrameworksDirectory], .when(platforms: [.macOS]))]
    : []
let testingLinkerSettings: [LinkerSetting] = hasDeveloperTestingFramework
    ? [.unsafeFlags(
        [
            "-F", developerFrameworksDirectory,
            "-framework", "Testing",
            "-Xlinker", "-rpath",
            "-Xlinker", developerFrameworksDirectory,
            "-Xlinker", "-rpath",
            "-Xlinker", developerLibrariesDirectory
        ],
        .when(platforms: [.macOS])
    )]
    : []
let swiftLanguageSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "SafeScreen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SafeScreenStage0",
            targets: ["SafeScreenStage0"]
        ),
        .library(
            name: "SafeScreenStage0Core",
            targets: ["SafeScreenStage0Core"]
        )
    ],
    targets: [
        .target(
            name: "SafeScreenStage0Core",
            swiftSettings: swiftLanguageSettings
        ),
        .executableTarget(
            name: "SafeScreenStage0",
            dependencies: ["SafeScreenStage0Core"],
            swiftSettings: swiftLanguageSettings,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "SafeScreenStage0CoreTests",
            dependencies: ["SafeScreenStage0Core"],
            swiftSettings: swiftLanguageSettings + testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        )
    ]
)
