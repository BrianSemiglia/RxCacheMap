# RxCacheMap

[![CI Status](https://img.shields.io/travis/brian.semiglia@gmail.com/RxCacheMap.svg?style=flat)](https://travis-ci.org/brian.semiglia@gmail.com/RxCacheMap)
[![Version](https://img.shields.io/cocoapods/v/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)
[![License](https://img.shields.io/cocoapods/l/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)
[![Platform](https://img.shields.io/cocoapods/p/RxCacheMap.svg?style=flat)](https://cocoapods.org/pods/RxCacheMap)

## Description

Cache/memoize the output of `RxSwift.Observables` using cacheMap, cacheFlatMap, cacheFlatMapLatest and cacheFlatMapUntilExpired.

## Usage

```swift
events.cacheMap { x -> Result in
    // Closure executed once per unique `x`, replayed when not unique
    expensiveOperation(x)
}

events.cacheMap(whenExceeding: 1) { x -> Result in
    // Closure executed once per unique `x` when operation exceeds duration, replayed when not unique
    expensiveOperation(x)
}

events.cacheFlatMap { x -> Observable<Result> in
    // Closure executed once per unique `x`, replayed when not unique
    expensiveOperation(x)
}

events.cacheFlatMapLatest { x -> Observable<Result> in
    // Closure executed once per unique `x`, replayed when not unique
    // Any in-flight plays/replays are canceled by subsequent inputs
    expensiveOperation(x)
}

events.cacheFlatMapInvalidatingOn { x -> Observable<(Result, Date)> in
    // Closure executed once per unique `x`, replayed when input not unique, cache invalidated when date returned is greater than or equal to date of event
    expensiveOperation(x).map { output in 
        return (output, Date() + hours(1))
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
