Pod::Spec.new do |s|
  s.name = 'TritonKit'
  s.version = '0.2.13'
  s.summary = 'Embedded debug runtime for TritonKit iOS view inspection.'
  s.description = 'TritonKit embeds a DEBUG-only runtime in an iOS app so the Triton CLI can inspect hierarchy, accessibility, geometry, screenshots, and supported in-app controls during development.'
  s.homepage = 'https://github.com/NeptuneKit/TritonKit'
  s.license = {
    :type => 'Custom',
    :text => 'TritonKit is in active development. See the repository for current licensing and usage terms.'
  }
  s.author = { 'NeptuneKit' => 'https://github.com/NeptuneKit' }
  s.source = { :git => 'https://github.com/NeptuneKit/TritonKit.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = {
    'ENABLE_APPINTENTS_DEPLOYMENT_AWARE_PROCESSING' => 'NO',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -D TRITONKIT_COCOAPODS_SINGLE_POD',
    'OTHER_SWIFT_FLAGS[config=Debug]' => '$(inherited) -D TRITONKIT_COCOAPODS_SINGLE_POD -D TRITONKIT_RUNTIME_ENABLED'
  }
  s.source_files = [
    'Sources/TritonKit/**/*.swift',
    'Sources/TritonKitShared/**/*.swift'
  ]
  s.frameworks = 'Foundation', 'UIKit', 'CoreGraphics'
end
