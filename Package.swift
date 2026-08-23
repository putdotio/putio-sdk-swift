// swift-tools-version:6.2

import PackageDescription

let package = Package(
  name: "PutioSDK",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
    .macCatalyst(.v26),
    .tvOS(.v26),
    .watchOS(.v26),
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
      path: "PutioSDK/Classes",
      // Keep in sync with the CocoaPods `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT`
      // setting in podspec_helper.rb so both distribution surfaces share one concurrency posture.
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
      ]
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
    .testTarget(
      name: "PutioSDKStrictConcurrencyTests",
      dependencies: ["PutioSDK"],
      path: "Tests/PutioSDKStrictConcurrencyTests",
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
  ],
  swiftLanguageModes: [
    .v5
  ]
)
