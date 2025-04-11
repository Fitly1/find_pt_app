require 'yaml'
# Load pubspec.yaml from three levels up (the project root)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  # Build path to firebase_core's version file (assuming it’s in the firebase_core plugin folder)
  firebase_core_script = File.join(File.expand_path('../../../', __FILE__), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "Using Firebase SDK version '#{firebase_sdk_version}' defined in firebase_core plugin"
  end
end

# Fallback: If firebase_sdk_version is still nil, use 11.10.0
firebase_sdk_version ||= '11.10.0'

Pod::Spec.new do |s|
  # Set the pod name to "cloud_functions" (not your app’s name)
  s.name             = "cloud_functions"
  s.version          = library_version
  s.summary          = "Cloud Functions plugin for Flutter."
  s.description      = "A Flutter plugin that provides an API for Firebase Cloud Functions."
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  # Load the LICENSE file from three levels up
  s.license          = { :type => 'Apache 2.0', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = "The Chromium Authors"
  
  # For a local pod, you can set the source to the current directory:
  s.source           = { :path => '.' }
  
  # Point to your source files — adjust the pattern if needed.
  s.source_files     = 'cloud_functions/Sources/**/*.{h,m,swift}'
  # If you have public headers in an include folder, uncomment the next line and adjust the path:
  # s.public_header_files = 'cloud_functions/Sources/cloud_functions/include/*.h'
  
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  
  # Flutter dependency
  s.dependency 'Flutter'
  
  # Firebase dependencies: Ensure these match your Firebase versions across plugins.
  s.dependency 'firebase_core'
  s.dependency 'Firebase/Functions', firebase_sdk_version
  
  s.static_framework = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
