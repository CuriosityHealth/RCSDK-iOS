#
# Be sure to run `pod lib lint RCSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RCSDK'
  s.version          = '0.1.0'
  s.summary          = 'A short description of RCSDK.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/curiosityhealth/RCSDK-iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jdkizer9' => 'james.kizer@gmail.com' }
  s.source           = { :git => 'https://github.com/curiosityhealth/RCSDK-iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'

  s.source_files = 'RCSDK/Classes/**/*'
  
  s.dependency 'Gloss', '~> 2.0'
  s.dependency 'ResearchKit', '~> 1.5'
  s.dependency 'ResearchSuiteExtensions', '~> 0.22'
  s.dependency 'ResearchSuiteTaskBuilder', '~> 0.13'
  s.dependency 'ResearchSuiteResultsProcessor', '~> 0.9'
  s.dependency 'ResearchSuiteApplicationFramework', '~> 0.23'
  s.dependency 'LS2SDK'
  s.dependency 'SnapKit', '~> 4.0'
  s.dependency 'QRCodeReader.swift', '~> 9'
  s.dependency 'Alamofire'
  s.dependency 'CryptoSwift'
  s.dependency 'JSONWebToken'

end
