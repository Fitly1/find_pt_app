#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_keyboard_visibility.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_keyboard_visibility'
  s.version          = '0.0.1'
  s.summary          = 'flutter_keyboard_visibility'
  s.description      = <<-DESC
Flutter keyboard visibility
                       DESC
  s.homepage         = 'https://github.com/MisterJimson/flutter_keyboard_visibility'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jason Rai' => 'jason.c.rai@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
end
