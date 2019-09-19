#
# Be sure to run `pod lib lint RCSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RCSDK'
  s.version          = '0.2.0'
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
  s.license          = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author           = { 'jdkizer9' => 'james.kizer@gmail.com' }
  s.source           = { :git => 'https://github.com/curiosityhealth/RCSDK-iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'

  s.subspec 'Core' do |core|
    core.source_files = 'Source/RCSDK/Classes/**/*'
    core.dependency 'Gloss', '~> 2.0'
    core.dependency 'ResearchKit', '~> 1.6'
    core.dependency 'ResearchSuiteExtensions', '~> 0.25'
    core.dependency 'ResearchSuiteTaskBuilder', '~> 0.13'
    core.dependency 'ResearchSuiteResultsProcessor', '~> 0.9'
    core.dependency 'LS2SDK'
    core.dependency 'SnapKit', '~> 4.0'
    core.dependency 'QRCodeReader.swift', '~> 9'
    core.dependency 'Alamofire'
    core.dependency 'CryptoSwift'
    core.dependency 'JSONWebToken'
  end

  s.subspec 'RSAFSupport' do |rsaf|
    rsaf.source_files = 'Source/RSAFSupport/Classes/**/*'
    rsaf.dependency 'RCSDK/Core'
    rsaf.dependency 'ResearchSuiteApplicationFramework', '~> 0.28'
  end

  s.default_subspec = 'Core'

end
