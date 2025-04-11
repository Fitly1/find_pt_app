require 'yaml'
# Load pubspec.yaml from three levels up (repository root)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  # Build path to firebase_core's firebase_sdk_version.rb script from the repository root.
  firebase_core_script = File.join(File.expand_path('../../../', __FILE__), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "Using Firebase SDK version '#{firebase_sdk_version}' defined in firebase_core plugin"
  end
end

Pod::Spec.new do |s|
  s.name             = "firebase_app_check"
  s.module_name      = "firebase_app_check"
  s.version          = library_version
  s.summary          = pubspec['description'] || "Firebase App Check plugin for Flutter."
  s.description      = pubspec['description'] || "A Flutter plugin that provides functionality for Firebase App Check."
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  # Load the LICENSE from three levels up
  s.license          = { :type => 'Apache 2.0', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = "The Chromium Authors"
  s.source           = { :path => '.' }
  
  s.source_files     = 'firebase_app_check/Sources/firebase_app_check/**/*.{h,m,swift}'
  s.public_header_files = 'firebase_app_check/Sources/firebase_app_check/include/*.h'
  
  s.ios.deployment_target = '13.0'
  
  s.swift_version = '5.0'
  
  s.dependency 'Flutter'
  
  s.dependency 'firebase_core'
  s.dependency 'Firebase/CoreOnly', "~> #{firebase_sdk_version}"
  s.dependency 'FirebaseAppCheck', "~> #{firebase_sdk_version}"
  
  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-appcheck\\\"",
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
