// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "xcb",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xcb", targets: ["xcb"]),
    ],
    targets: [
        .executableTarget(name: "xcb", dependencies: ["XCBCore"]),
        .target(name: "XCBCore"),
        // Lowercase `tests/` holds both the Swift unit tests and the bats CLI tests
        .testTarget(name: "XCBCoreTests", dependencies: ["XCBCore"], path: "tests/XCBCoreTests"),
    ]
)
