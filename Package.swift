// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumenDesk",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LumenDesk", targets: ["LumenDesk"])],
    targets: [
        .target(name: "USBSerial"),
        .executableTarget(name: "LumenDesk", dependencies: ["USBSerial"]),
        .testTarget(name: "LumenDeskTests", dependencies: ["LumenDesk"])
    ]
)
