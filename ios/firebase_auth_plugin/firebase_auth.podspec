require 'yaml'
# Load pubspec.yaml from three levels up (repository root)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

if defined?($FirebaseSDKVersion)
  Pod::UI.puts "Using user specified Firebase SDK version '#{$FirebaseSDKVersion}'"
  firebase_sdk_version = $FirebaseSDKVersion
else
  # Build path to firebase_core's firebase_sdk_version.rb from the repository root.
  firebase_core_script = File.join(File.expand_path('../../../', __FILE__), 'firebase_core/ios/firebase_sdk_version.rb')
  if File.exist?(firebase_core_script)
    require firebase_core_script
    firebase_sdk_version = firebase_sdk_version!
    Pod::UI.puts "Using Firebase SDK version '#{firebase_sdk_version}' defined in firebase_core plugin"
  end
end

Pod::Spec.new do |s|
  s.name             = "firebase_auth"  # Explicit plugin name
  s.module_name      = "firebase_auth"  # Helps with module import resolution
  s.version          = library_version
  s.summary          = pubspec['description'] || "Firebase Auth plugin for Flutter."
  s.description      = pubspec['description'] || "A Flutter plugin that provides Firebase authentication functionality."
  s.homepage         = pubspec['homepage'] || "https://firebase.flutter.dev/"
  # Use absolute path for LICENSE (three levels up)
  s.license          = { :type => 'Apache 2.0', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = "The Chromium Authors"
  s.source           = { :path => '.' }

  # Adjust file patterns to match your directory structure.
  # If your source files (implementation) are located under:
  # firebase_auth/Sources/firebase_auth/
  s.source_files     = 'firebase_auth/Sources/firebase_auth/**/*.{h,m,swift}'
  # Public headers are assumed to be under:
  # firebase_auth/Sources/firebase_auth/include/Public/
  s.public_header_files = 'firebase_auth/Sources/firebase_auth/include/Public/**/*.h'
  # Private headers (if any) are assumed under:
  # firebase_auth/Sources/firebase_auth/include/Private/
  s.private_header_files = 'firebase_auth/Sources/firebase_auth/include/Private/**/*.h'

  s.ios.deployment_target = '13.0'
  s.dependency 'Flutter'
  s.dependency 'firebase_core'
  s.dependency 'Firebase/Auth', "~> #{firebase_sdk_version}"

  s.static_framework = true
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => "LIBRARY_VERSION=\\\"#{library_version}\\\" LIBRARY_NAME=\\\"flutter-fire-auth\\\"",
    'DEFINES_MODULE' => 'YES'
  }
end
