# RxCacheMap

[![CI Status](https://img.shields.io/travis/brian.semiglia@gmail.com/RxCacheMap.svg?style=flat)](https://travis-ci.org/brian.semiglia@gmail.com/RxCacheMap)
[![Version](https://img.shields.io/cocoapods/v/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)
[![License](https://img.shields.io/cocoapods/l/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)
[![Platform](https://img.shields.io/cocoapods/p/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)

## Description

Cache/memoize the output of `RxSwift.Observables` using cacheMap, cacheFlatMap, cacheFlatMapLatest and cacheFlatMapUntilExpired.

## Usage

```swift
queries.cacheMap { x -> URL? in
    // Closure executed once per unique `x`, replayed when not unique
    URL(string: "http://..." + x)
}

queries.cacheFlatMap { x -> Observable<JSON> in
    // Closure executed once per unique `x`, replayed when not unique
    NetworkRequest(x).map { /* parse data */ }
}

queries.cacheFlatMapLatest { x -> Observable<JSON> in
    // Closure executed once per unique `x`, replayed when not unique
    // Any in-flight plays/replays are canceled by subsequent inputs
    NetworkRequest(x).map { /* parse data */ }
}

queries.cacheFlatMapInvalidatingOn { x -> Observable<(JSON, Date)> in
    // Closure executed once per unique `x`, replayed when input not unique until date 
    // of output is greater than or equal to date of subsequent replay
    NetworkRequest(x).map { response in 
        return (response.JSON, response.expirationDate)
    }
}
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

RxCacheMap is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'RxCacheMap'
```

## Author

brian.semiglia@gmail.com

## License

RxCacheMap is available under the MIT license. See the LICENSE file for more info.
