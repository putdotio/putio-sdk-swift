podspec_helper_path = File.expand_path('podspec_helper.rb', __dir__)
podspec_helper = Module.new
podspec_helper.module_eval(File.read(podspec_helper_path), podspec_helper_path)

Pod::Spec.new do |s|
  podspec_helper::PutioSDKPodspec.configure(s, name: 'PutioSDK', module_name: 'PutioSDK')
end
