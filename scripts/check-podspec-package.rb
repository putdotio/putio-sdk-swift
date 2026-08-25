#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cocoapods'
require 'fileutils'
require 'pathname'
require 'tmpdir'

repository_root = File.expand_path('..', __dir__)
package_inputs = %w[LICENSE PutioSDK PutioSDK.podspec VERSION podspec_helper.rb]
required_support_files = %w[VERSION podspec_helper.rb]

Dir.mktmpdir('putio-sdk-pod-package-') do |temporary_directory|
  package_root = File.join(temporary_directory, 'PutioSDK')
  FileUtils.mkdir_p(package_root)

  package_inputs.each do |path|
    FileUtils.cp_r(File.join(repository_root, path), package_root)
  end

  spec = Pod::Specification.from_file(File.join(package_root, 'PutioSDK.podspec'))
  specs_by_platform = spec.available_platforms.to_h { |platform| [platform, [spec]] }
  Pod::Sandbox::PodDirCleaner.new(Pathname(package_root), specs_by_platform).clean!

  missing_files = required_support_files.reject { |path| File.file?(File.join(package_root, path)) }
  abort "CocoaPods package pruning removed: #{missing_files.join(', ')}" unless missing_files.empty?

  load File.join(package_root, 'podspec_helper.rb')
  packaged_version = PutioSDKPodspec.version
  expected_version = File.read(File.join(repository_root, 'VERSION')).strip
  abort "Packaged podspec version #{packaged_version.inspect} does not match #{expected_version.inspect}" unless packaged_version == expected_version

  def configure_putio_sdk_spec(...)
    raise 'A downloaded podspec replaced the active podspec helper'
  end

  reloaded_spec = Pod::Specification.from_file(File.join(repository_root, 'PutioSDK.podspec'))
  abort "Reloaded podspec version #{reloaded_spec.version} does not match #{expected_version}" unless reloaded_spec.version.to_s == expected_version

  puts "CocoaPods package support files preserved for PutioSDK #{packaged_version}"
end
