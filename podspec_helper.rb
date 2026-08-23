# frozen_string_literal: true

def putio_sdk_version
  File.read(File.join(__dir__, 'VERSION')).strip
end

def configure_putio_sdk_spec(spec, name:, module_name: nil)
  spec.name             = name
  spec.module_name      = module_name if module_name
  spec.version          = putio_sdk_version
  spec.swift_version    = '5.0'
  # Keep in sync with the SwiftPM `NonisolatedNonsendingByDefault` upcoming feature in
  # Package.swift. Pre-Xcode-26 toolchains silently ignore this setting (see
  # docs/ARCHITECTURE.md#swift-concurrency-posture for the CocoaPods caveat).
  spec.pod_target_xcconfig = { 'SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT' => 'YES' }

  spec.summary          = 'Swift SDK for the put.io API.'
  spec.description      = 'Swift SDK for the [put.io API](https://api.put.io).'

  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.author           = { 'put.io' => 'devs@put.io' }

  spec.homepage         = 'https://github.com/putdotio/putio-sdk-swift'
  spec.source           = { :git => 'https://github.com/putdotio/putio-sdk-swift.git', :tag => "v#{spec.version}" }
  spec.social_media_url = 'https://twitter.com/putdotio'

  spec.ios.deployment_target = '26.0'
  spec.tvos.deployment_target = '26.0'
  spec.watchos.deployment_target = '26.0'
  spec.source_files = 'PutioSDK/Classes/**/*'
end
