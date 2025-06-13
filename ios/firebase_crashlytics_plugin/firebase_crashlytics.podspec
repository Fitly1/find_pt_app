require 'yaml'
# Load pubspec.yaml from three levels up (the repository root)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  # Build path to firebase_core's firebase_sdk_version.rb, from three levels up
  firebase_core_script = File.join(File.expand_path('../../../', __FILE__), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "Using Firebase SDK version '#{firebase_sdk_version}' defined in firebase_core plugin"
  end
end

# If firebase_sdk_version is nil or empty, default to 11.10.0
if firebase_sdk_version.nil? || firebase_sdk_version.strip.empty?
  firebase_sdk_version = '11.10.0'
end

Pod::Spec.new do |s|
  # Explicitly name your plugin so Xcode sees it as firebase_crashlytics
  s.name             = "firebase_crashlytics"
  s.module_name      = "firebase_crashlytics"
  s.version          = library_version
  s.summary          = pubspec['description'] || "Firebase Crashlytics plugin for Flutter."
  s.description      = pubspec['description'] || "A Flutter plugin that integrates with Firebase Crashlytics."
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  # Load LICENSE from three levels up
  s.license          = { :type => 'Apache 2.0', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = "The Chromium Authors"
  s.source           = { :path => '.' }

  # Adjust these patterns to your actual folder structure:
  # You have .m, .h, and possibly .swift files under:
  # firebase_crashlytics/Sources/firebase_crashlytics/
  s.source_files       = 'firebase_crashlytics/Sources/firebase_crashlytics/**/*.{h,m,swift}'

  # Public header files in the `include` folder
  s.public_header_files = 'firebase_crashlytics/Sources/firebase_crashlytics/include/*.h'

  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.0'

  # Dependencies
  s.dependency 'Flutter'
  s.dependency 'firebase_core'
  s.dependency 'Firebase/Crashlytics', "~> #{firebase_sdk_version}"

  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-crashlytics\\\"",
    'DEFINES_MODULE' => 'YES'
  }
end
