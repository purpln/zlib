// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "zlib",
    products: [.library(name: "zlib", targets: ["zlib"])],
    targets: [.systemLibrary(name: "zlib")]
)
