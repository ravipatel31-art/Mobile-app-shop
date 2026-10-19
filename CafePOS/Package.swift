// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CafePOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project contains exactly one library product = the main app.
        .library(name: "CafePOS", targets: ["CafePOS"]),
    ],
    targets: [
        .target(
            name: "CafePOS",
            swiftSettings: [
                // Port a large Flutter app; Swift 5 mode avoids strict-concurrency
                // errors blocking the first green build. Migrate to v6 later.
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
