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
    name: "OverlayBrowser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OverlayBrowser",
            targets: ["OverlayBrowser"]
        ),
        .library(
            name: "OverlayBrowserCore",
            targets: ["OverlayBrowserCore"]
        )
    ],
    targets: [
        .target(
            name: "OverlayBrowserCore",
            swiftSettings: swiftLanguageSettings
        ),
        .target(
            name: "OverlayBrowserWebKit",
            swiftSettings: swiftLanguageSettings,
            linkerSettings: [
                .linkedFramework("WebKit")
            ]
        ),
        .executableTarget(
            name: "OverlayBrowser",
            dependencies: ["OverlayBrowserCore", "OverlayBrowserWebKit"],
            swiftSettings: swiftLanguageSettings,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("WebKit")
            ]
        ),
        .testTarget(
            name: "OverlayBrowserCoreTests",
            dependencies: ["OverlayBrowserCore"],
            swiftSettings: swiftLanguageSettings + testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
        .testTarget(
            name: "OverlayBrowserWebKitTests",
            dependencies: ["OverlayBrowserWebKit"],
            swiftSettings: swiftLanguageSettings + testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
        .testTarget(
            name: "OverlayFocusGuardExtensionTests",
            swiftSettings: swiftLanguageSettings + testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        )
    ]
)
