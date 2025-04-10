require 'yaml'

pubspec = YAML.load_file(File.join('..', '..', 'pubspec.yaml'))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "#{pubspec['name']}: Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  firebase_core_script = File.join(File.expand_path('..', File.expand_path('..', File.dirname(__FILE__))), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "#{pubspec['name']}: Using Firebase SDK version '#{firebase_sdk_version}' defined in 'firebase_core_plugin'"
  end
end

# Fallback: If firebase_sdk_version is still nil, assign it to '11.7.0'
firebase_sdk_version ||= '11.7.0'

Pod::Spec.new do |s|
  s.name             = 'firebase_core'
  s.version          = library_version
  s.summary          = "Firebase Core for Flutter."
  s.description      = "A Flutter plugin providing core functionality for integrating Firebase services into find_pt_app. " + (pubspec['description'] || "")
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  s.license          = { :type => 'Apache 2.0', :file => '../LICENSE' }
  s.authors          = 'The Chromium Authors'
  # Dummy source to satisfy CocoaPods' requirement.
  s.source           = { :git => "https://github.com/dummy/dummy.git", :tag => s.version }
  s.source_files     = 'firebase_core/Sources/firebase_core/**/*.{h,m}'
  s.public_header_files = 'firebase_core/Sources/firebase_core/include/**/*.h'

  s.ios.deployment_target = '13.0'

  # Flutter dependency
  s.dependency 'Flutter'

  # Firebase dependency
  s.dependency 'Firebase/CoreOnly', firebase_sdk_version

  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-core\\\"",
    'DEFINES_MODULE' => 'YES'
  }
end
