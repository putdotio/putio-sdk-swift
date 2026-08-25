require_relative 'podspec_helper'

Pod::Spec.new do |s|
  PutioSDKPodspec.configure(s, name: 'PutioSDK', module_name: 'PutioSDK')
end
