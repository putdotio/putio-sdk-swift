// swift-tools-version:6.2

import PackageDescription

let package = Package(
  name: "PutioSDK",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
    .macCatalyst(.v26),
  ],
  products: [
    .library(
      name: "PutioSDK",
      targets: ["PutioSDK"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "PutioSDK",
      dependencies: [],
      path: "PutioSDK/Classes"
    ),
    .testTarget(
      name: "PutioSDKTests",
      dependencies: ["PutioSDK"],
      path: "Tests/PutioSDKTests"
    ),
    .testTarget(
      name: "PutioSDKLiveTests",
      dependencies: ["PutioSDK"],
      path: "Tests/PutioSDKLiveTests"
    ),
  ],
  swiftLanguageModes: [
    .v5
  ]
)
