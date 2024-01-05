import XCTest
import RxCacheMap
import RxSwift
import RxTest
import RxBlocking

class RxCacheTests: XCTestCase {
        
    func testCacheMap() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 1])
                .cacheMap { x -> Int in
                    cacheMisses += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMisses,
            1
        )
    }
    
    func testCacheMapReset() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 2, 1, 3])
                .cacheMap(when: { $0 == 1 }) { x -> Int in
                    cacheMisses += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 2, 1, 3]
        )
        XCTAssertEqual(cacheMisses, 3)
    }
    
    func testCacheFlatMapSingle() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 1])
                .cacheFlatMap { x -> Observable<Int> in
                    Observable.create { o in
                        cacheMisses += 1
                        o.on(.next(x))
                        o.on(.completed)
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(cacheMisses, 1)
    }
    
    func testCacheFlatMapMultiple() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 1])
                .cacheFlatMap { _ -> Observable<String> in
                    Observable<String>.create {
                        cacheMisses += 1
                        $0.on(.next("1"))
                        $0.on(.next("2"))
                        $0.on(.next("3"))
                        $0.on(.next("4"))
                        $0.on(.next("5"))
                        $0.on(.completed)
                        return Disposables.create()
                    }
                }
                .reduce("", accumulator: +)
                .toBlocking()
                .toArray(),
            ["1234512345"]
        )
        XCTAssertEqual(cacheMisses, 1)
    }
    
    func testCacheFlatMapReset() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 2, 1, 3])
                .cacheFlatMap(when: { $0 == 1 }) { x -> Observable<Int> in
                    Observable.create { o in
                        cacheMisses += 1
                        o.on(.next(x))
                        o.on(.completed)
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 2, 1, 3]
        )
        XCTAssertEqual(cacheMisses, 3)
    }
    
    func testCacheFlatMapLatest() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .merge(
                    Observable
                        .just(2)
                        .delay(.seconds(0), scheduler: MainScheduler.instance), // cancelled
                    Observable
                        .just(1)
                        .delay(.milliseconds(Int(0.5 * 1000)), scheduler: MainScheduler.instance), // succeeds
                    Observable
                        .just(1)
                        .delay(.seconds(2), scheduler: MainScheduler.instance) // succeeds from cache
                )
                .cacheFlatMapLatest { x in
                    Observable<Int>
                        .create { o in
                            cacheMisses += 1
                            o.on(.next(x))
                            o.on(.completed)
                            return Disposables.create()
                        }
                        .delay(
                            .seconds(1),
                            scheduler: MainScheduler.instance
                        )
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(cacheMisses, 2)
    }
    
    func testCacheFlatMapInvalidatingOnNever() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .merge(
                    Observable
                        .just(1)
                        .delay(.seconds(0), scheduler: MainScheduler.instance), // called
                    Observable
                        .just(1)
                        .delay(.milliseconds(Int(0.5 * 1000)), scheduler: MainScheduler.instance), // cached
                    Observable
                        .just(1)
                        .delay(.seconds(1), scheduler: MainScheduler.instance) // invalidate, called
                )
                .cacheFlatMapInvalidatingOn { (x: Int) -> Observable<(Int, Date)> in
                    Observable.create { o in
                        cacheMisses += 1
                        o.on(
                            .next((
                                x,
                                Date() + 2
                            ))
                        )
                        o.on(.completed)
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1, 1]
        )
        XCTAssertEqual(cacheMisses, 1)
    }
    
    func testCacheFlatMapInvalidatingOnSome() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .merge(
                    Observable
                        .just(1)
                        .delay(.seconds(0), scheduler: MainScheduler.instance), // called
                    Observable
                        .just(1)
                        .delay(.milliseconds(Int(0.5 * 1000)), scheduler: MainScheduler.instance), // cached
                    Observable
                        .just(1)
                        .delay(.seconds(1), scheduler: MainScheduler.instance) // invalidated, called
                )
                .cacheFlatMapInvalidatingOn { (x: Int) -> Observable<(Int, Date)> in
                    Observable.create { o in
                        cacheMisses += 1
                        o.on(
                            .next((
                                x,
                                Date() + 0.6
                            ))
                        )
                        o.on(.completed)
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1, 1]
        )
        XCTAssertEqual(cacheMisses, 2)
    }
    
    func testCacheMapWhenExceedingDurationAll() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 1])
                .cacheMap(whenExceeding: .seconds(1)) { x -> Int in
                    cacheMisses += 1
                    Thread.sleep(forTimeInterval: 2)
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(cacheMisses, 1)
    }
    
    func testCacheMapWhenExceedingDurationSome() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 3, 1, 3])
                .cacheMap(whenExceeding: .seconds(2)) { x -> Int in
                    cacheMisses += 1
                    Thread.sleep(forTimeInterval: TimeInterval(x))
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 3, 1, 3]
        )
        XCTAssertEqual(cacheMisses, 3)
    }
    
    func testCacheMapWhenExceedingDurationNever() {
        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable
                .from([1, 1])
                .cacheMap(whenExceeding: .seconds(2)) { x -> Int in
                    cacheMisses += 1
                    Thread.sleep(forTimeInterval: 1)
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(cacheMisses, 2)
    }
 
    func testDiskPersistenceMap() throws {

        // Separate cache instances are used but values are persisted between them.

        let cache: Persisting<Int, Int> = Persisting<Int, Int>.diskCache()
        cache.reset()

        var cacheMissesInitial: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1])
                .cacheMap(cache: .diskCache()) { x -> Int in
                    cacheMissesInitial += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMissesInitial,
            1
        )

        var cacheMissesSubsequent: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1])
                .cacheMap(cache: .diskCache()) { x -> Int in
                    cacheMissesSubsequent += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMissesSubsequent,
            0
        )
    }

    func testDiskPersistenceWithIDMap() throws {

        // Separate cache instances are used but values are persisted between them.

        let id = "id"
        let cache: Persisting<Int, Int> = Persisting<Int, Int>.diskCache(id: id)
        cache.reset()

        var cacheMissesInitial: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1])
                .cacheMap(cache: .diskCache(id: id)) { x -> Int in
                    cacheMissesInitial += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMissesInitial,
            1
        )

        var cacheMissesSubsequent: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1])
                .cacheMap(cache: .diskCache(id: id)) { x -> Int in
                    cacheMissesSubsequent += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMissesSubsequent,
            0
        )

        cache.reset()

        var cacheMisses2: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1])
                .cacheMap(cache: .diskCache(id: id)) { x -> Int in
                    cacheMisses2 += 1
                    return x
                }
                .toBlocking()
                .toArray(),
            [1, 1]
        )
        XCTAssertEqual(
            cacheMisses2,
            1
        )
    }

    func testDiskPersistenceFlatMap() {

        // Separate cache instances are used but values are persisted between them.

        let cache: Persisting<Int, Int> = .diskCache()
        cache.reset()

        var cacheMisses: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1, 1])
                .cacheFlatMap(cache: .diskCache()) { x -> Observable<Int> in
                    Observable.create {
                        cacheMisses += 1
                        $0.onNext(x)
                        $0.onCompleted()
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1, 1]
        )
        XCTAssertEqual(cacheMisses, 1)

        var cacheMisses2: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1, 1])
                .cacheFlatMap(cache: .diskCache()) { x -> Observable<Int> in
                    Observable.create {
                        cacheMisses2 += 1
                        $0.onNext(x)
                        $0.onCompleted()
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1, 1]
        )
        XCTAssertEqual(cacheMisses2, 0)

        cache.reset()

        var cacheMisses3: Int = 0
        try XCTAssertEqual(
            Observable.from([1, 1, 1])
                .cacheFlatMap(cache: .diskCache()) { x -> Observable<Int> in
                    Observable.create {
                        cacheMisses3 += 1
                        $0.onNext(x)
                        $0.onCompleted()
                        return Disposables.create()
                    }
                }
                .toBlocking()
                .toArray(),
            [1, 1, 1]
        )
        XCTAssertEqual(cacheMisses3, 1)
    }
}
