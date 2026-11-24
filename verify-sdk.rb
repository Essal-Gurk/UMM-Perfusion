require 'json'
require 'digest'

directory = File.expand_path(ARGV.fetch(0))
manifest = JSON.parse(File.read(File.join(directory, 'SDK.json')))
abort 'IsiXPluginKit API v1 / kit 1.0.0 required' unless
  manifest['name'] == 'IsiXPluginKit' &&
  manifest['apiVersion'] == 1 &&
  manifest['kitVersion'] == '1.0.0'
abort 'SDK needs an arm64 architecture' unless manifest.fetch('architectures').include?('arm64')
abort 'SDK requires a newer deployment target' unless
  Gem::Version.new(manifest.fetch('minimumSystem')) <= Gem::Version.new('15.0')

framework = File.join(directory, 'IsiXPluginKit.framework', 'Versions', 'A')
binary = File.join(framework, 'IsiXPluginKit')
abort 'SDK framework checksum mismatch' unless
  Digest::SHA256.file(binary).hexdigest == manifest.fetch('binarySHA256')
interface = 'arm64-apple-macos.swiftinterface'
path = File.join(framework, 'Modules', 'IsiXPluginKit.swiftmodule', interface)
abort 'SDK arm64 interface checksum mismatch' unless
  Digest::SHA256.file(path).hexdigest == manifest.fetch('interfaceSHA256').fetch(interface)
puts "Verified IsiXPluginKit #{manifest.fetch('kitVersion')} / API #{manifest.fetch('apiVersion')}, revision #{manifest.fetch('revision')}"
