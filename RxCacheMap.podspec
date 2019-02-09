#
# Be sure to run `pod lib lint RxCacheMap.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxCacheMap'
  s.version          = '0.1.4'
  s.summary          = 'A collection of caching RxSwift operators.'
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
  s.dependency 'RxSwift', '~> 4.4.0'
end
