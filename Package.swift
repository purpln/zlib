// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "zlib",
    products: [.library(name: "zlib", targets: ["zlib-swift"])],
    targets: [.systemLibrary(name: "zlib", pkgConfig: "zlib"), .target(name: "zlib-swift", dependencies: ["zlib"])]
)
