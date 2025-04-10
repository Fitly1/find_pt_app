require 'yaml'
# Go up three levels to reach the repository root (where pubspec.yaml resides)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "#{pubspec['name']}: Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  # Build the path to firebase_core's version script from the repository root
  firebase_core_script = File.join(File.expand_path('../../../', __FILE__), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "#{pubspec['name']}: Using Firebase SDK version '#{firebase_sdk_version}' defined in 'firebase_core_plugin'"
  end
end

# Fallback: If firebase_sdk_version remains nil, use a default version.
firebase_sdk_version ||= '11.7.0'

Pod::Spec.new do |s|
  s.name             = "cloud_functions"
  s.version          = library_version
  s.summary          = "Cloud Functions for Flutter."
  s.description      = "A Flutter plugin that provides an API for Firebase Cloud Functions."
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  # Use an absolute path for the LICENSE file from the repository root.
  s.license          = { :type => 'Apache 2.0', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = 'The Chromium Authors'
  # Dummy source to satisfy CocoaPods validation.
  s.source           = { :git => "https://github.com/dummy/dummy.git", :tag => s.version }
  s.source_files     = 'cloud_functions/Sources/cloud_functions/**/*.{h,m}'
  s.public_header_files = 'cloud_functions/Sources/cloud_functions/include/*.h'
  s.ios.deployment_target = '13.0'
  
  # Flutter dependency
  s.dependency 'Flutter'
  
  # Firebase dependencies
  s.dependency 'firebase_core'
  s.dependency 'Firebase/Functions', firebase_sdk_version
  
  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-fn\\\"",
    'DEFINES_MODULE' => 'YES'
  }
end
