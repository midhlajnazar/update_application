// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "update_application",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "update-application", targets: ["update_application"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "update_application",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
