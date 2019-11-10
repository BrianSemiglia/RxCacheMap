Pod::Spec.new do |s|
  s.name             = 'RxCacheMap'
  s.version          = '0.3.0'
  s.summary          = 'A collection of caching RxSwift operators.'
  s.description      = 'Cache/memoize the output of RxSwift.Observables using cacheMap, cacheFlatMap, cacheFlatMapLatest and cacheFlatMapInvalidatingOn.'
  s.homepage         = 'https://github.com/briansemiglia/RxCacheMap'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Brian Semiglia' => 'brian.semiglia@gmail.com' }
  s.source           = {
      :git => 'https://github.com/briansemiglia/RxCacheMap.git',
      :tag => s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/brians_'
  s.ios.deployment_target = '8.0'
  s.macos.deployment_target = '10.9'
  s.source_files = 'RxCacheMap/Classes/**/*'
  s.swift_version = '5.1'
  s.dependency 'RxSwift', '~> 5.0'
end
