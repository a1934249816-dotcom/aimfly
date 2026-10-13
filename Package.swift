// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CallJournalCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CallJournalCore", targets: ["CallJournalCore"])],
    targets: [
        .target(name: "CallJournalCore"),
        .testTarget(name: "CallJournalCoreTests", dependencies: ["CallJournalCore"])
    ]
)
