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
    Pod::UI.puts "#{pubspec['name']}: Using Firebase SDK version '#{firebase_sdk_version}' defined in 'firebase_core'"
  end
end

Pod::Spec.new do |s|
  s.name             = 'cloud_firestore'
  s.version          = library_version
  s.summary          = "Flutter plugin for Cloud Firestore."
  s.description      = "A Flutter plugin for Cloud Firestore that enables seamless integration with Cloud Firestore on iOS."
  s.homepage         = "https://pub.dev/packages/cloud_firestore"
  s.license          = { :type => "MIT", :file => "../LICENSE" }
  s.authors          = 'The Flutter Team'
  s.source           = { :path => "." }
  s.source_files     = "cloud_firestore/Sources/cloud_firestore/**/*.{h,m}"
  s.public_header_files = "cloud_firestore/Sources/cloud_firestore/include/Public/**/*.h"
  s.private_header_files = "cloud_firestore/Sources/cloud_firestore/include/Private/**/*.h"

  s.ios.deployment_target = '13.0'
  s.dependency 'Flutter'
  s.dependency 'firebase_core'
  s.dependency 'Firebase/Firestore', '11.10.0'

  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-fst\\\"",
    'DEFINES_MODULE' => 'YES'
  }
end
