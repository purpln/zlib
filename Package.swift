// swift-tools-version: 5.5

import PackageDescription

let package = Package(name: "zlib", products: [
    .library(name: "zlib", targets: ["zlib"]),
], targets: [
    .systemLibrary(name: "zlib", pkgConfig: "zlib"),
])
