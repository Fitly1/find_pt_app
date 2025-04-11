require 'yaml'
# Load pubspec.yaml from three levels up (the repository root)
pubspec = YAML.load_file(File.expand_path('../../../pubspec.yaml', __FILE__))
library_version = pubspec['version'].gsub('+', '-')

Pod::Spec.new do |s|
  s.name             = "flutter_email_sender"       # Explicit plugin name
  s.module_name      = "flutter_email_sender"       # Module name for Xcode
  s.version          = library_version
  s.summary          = pubspec['description'] || "Flutter Email Sender plugin."
  s.description      = pubspec['description'] || "A Flutter plugin for sending emails from the device."
  s.homepage         = pubspec['homepage'] || "https://pub.dev/packages/flutter_email_sender"
  # Load LICENSE from three levels up
  s.license          = { :type => 'MIT', :file => File.expand_path('../../../LICENSE', __FILE__) }
  s.authors          = "Flutter Email Sender Authors <email@example.com>"
  s.source           = { :path => '.' }
  
  # Adjust the file pattern if your Swift source files are in a different folder.
  s.source_files       = 'flutter_email_sender/Sources/flutter_email_sender/**/*.swift'
  
  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.0'
  
  # Flutter dependency
  s.dependency 'Flutter'
  
  # If you have a .xcprivacy resource file:
  s.resource_bundles = {
    "flutter_email_sender_privacy" => ["flutter_email_sender/Sources/flutter_email_sender/PrivacyInfo.xcprivacy"]
  }
  
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
