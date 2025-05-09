// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Gtranslator",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "Gtranslator", targets: ["GTranslatorMenu"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GTranslatorMenu",
            dependencies: [],
            exclude: ["Info.plist"])
    ]
)