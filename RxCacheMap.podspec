#
# Be sure to run `pod lib lint RxCacheMap.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxCacheMap'
  s.version          = '0.1.1'
  s.summary          = 'A collection of caching RxSwift operators.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'Cache the output of rx observables using cacheMap, cacheFlatMap, cacheFlatMapLatest and cacheFlatMapUntilExpired.'
  s.homepage         = 'https://github.com/briansemiglia/RxCacheMap'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'brian.semiglia@gmail.com' => 'brian.semiglia@gmail.com' }
  s.source           = {
      :git => 'https://github.com/briansemiglia/RxCacheMap.git',
      :tag => s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/brians_'
  s.ios.deployment_target = '8.0'
  s.macos.deployment_target = '10.14'
  s.source_files = 'RxCacheMap/Classes/**/*'
  s.swift_version = '4.2'
  
  # s.resource_bundles = {
  #   'RxCacheMap' => ['RxCacheMap/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'RxSwift', '~> 4.4.0'
end
