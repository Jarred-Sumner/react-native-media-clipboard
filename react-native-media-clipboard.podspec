require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))


folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'
folly_version = '2018.10.22.00'

Pod::Spec.new do |s|
  s.name         = "react-native-media-clipboard"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = <<-DESC
                  react-native-media-clipboard
                   DESC
  s.homepage     = "https://github.com/github_account/react-native-media-clipboard"
  s.license      = "MIT"
  # s.license    = { :type => "MIT", :file => "FILE_LICENSE" }
  s.authors      = { "Your Name" => "yourname@email.com" }
  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/github_account/react-native-media-clipboard.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,swift}"
  s.requires_arc = true
  s.default_subspec = 'Bridge'


  s.swift_version = '5.0'

  s.dependency "React"


  s.subspec 'Bridge' do |lite|

    lite.pod_target_xcconfig = {  "LIBRAY_SEARCH_PATHS" => "\"$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)\"" }
  end

  s.subspec 'JSI' do |jsi|
    jsi.source_files = "ios/**/*.{h,m,swift,mm}"
    jsi.dependency "React-jsi"
    jsi.dependency "React-jsiexecutor"
    jsi.dependency "ReactCommon/jscallinvoker"
    jsi.dependency 'ReactCommon/turbomodule/core'
    jsi.dependency 'React-cxxreact'
    jsi.dependency 'Folly'
    jsi.pod_target_xcconfig = { "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/Folly\"", 'DEFINES_MODULE' => 'YES', 'ENABLE_BITCODE' => "NO", "LIBRAY_SEARCH_PATHS" => "\"$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)\"" }
    jsi.compiler_flags  = folly_compiler_flags
  end


end

