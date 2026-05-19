Pod::Spec.new do |s|
  s.name = 'TritonKitShared'
  s.version = '0.1.0'
  s.summary = 'Shared wire models for TritonKit.'
  s.description = 'TritonKitShared contains Codable transport, input, observation, and archive models shared by the TritonKit embedded runtime and CLI tooling.'
  s.homepage = 'https://github.com/NeptuneKit/TritonKit'
  s.license = {
    :type => 'Custom',
    :text => 'TritonKit is in active development. See the repository for current licensing and usage terms.'
  }
  s.author = { 'NeptuneKit' => 'https://github.com/NeptuneKit' }
  s.source = { :git => 'https://github.com/NeptuneKit/TritonKit.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.9'
  s.source_files = 'Sources/TritonKitShared/**/*.swift'
end
