import XCTest
import RxCacheMap
import RxSwift

class RxCacheTests: XCTestCase {
    
    let cleanup = DisposeBag()
    
    func testCacheMap() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
        Observable
            .from([
                1,
                1,
            ])
            .cacheMap { x -> Int in
                cacheMisses += 1
                return x
            }
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssertEqual(cacheMisses, 1)
                    XCTAssertEqual(responses.count, 2)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 0.25)
    }
    
    func testCacheMapReset() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
        Observable
            .from([
                1,
                2,
                1,
                3
            ])
            .cacheMap(
                transform: { x -> Int in
                    cacheMisses += 1
                    return x
                },
                when: { $0 == 1 }
            )
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssertEqual(cacheMisses, 3)
                    XCTAssertEqual(responses.count, 4)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 0.25)
    }
    
    func testCacheFlatMapSingle() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
        Observable
            .from([
                1,
                1
            ])
            .cacheFlatMap { x -> Observable<Int> in
                Observable.create { o in
                    cacheMisses += 1
                    o.on(.next(x))
                    o.on(.completed)
                    return Disposables.create()
                }
            }
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssert(cacheMisses == 1)
                    XCTAssert(responses.count == 2)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 0.25)
    }
    
    func testCacheFlatMapMultiple() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [String] = []
        Observable
            .from([
                1,
                1,
            ])
            .cacheFlatMap { _ -> Observable<String> in
                Observable<String>
                    .create {
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
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssertEqual(cacheMisses, 1)
                    XCTAssertEqual(responses.reduce("", +), "1234512345")
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 0.25)
    }
    
    func testCacheFlatMapReset() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
        Observable
            .from([
                1,
                2,
                1,
                3
            ])
            .cacheFlatMap(
                observable: { x -> Observable<Int> in
                    Observable.create { o in
                        cacheMisses += 1
                        o.on(.next(x))
                        o.on(.completed)
                        return Disposables.create()
                    }
                },
                when: { $0 == 1 }
            )
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssertEqual(cacheMisses, 3)
                    XCTAssertEqual(responses.count, 4)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 0.25)
    }
    
    func testCacheFlatMapLatest() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
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
                    .delay(.seconds(1), scheduler: MainScheduler.instance)
            }
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssert(cacheMisses == 2)
                    XCTAssert(responses == [1, 1])
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 4)
    }
    
    func testCacheFlatMapInvalidatingOnNever() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
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
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssertEqual(cacheMisses, 1)
                    XCTAssertEqual(responses.count, 3)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 1.2)
    }
    
    func testCacheFlatMapInvalidatingOnSome() {
        let x = expectation(description: "")
        var cacheMisses: Int = 0
        var responses: [Int] = []
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
            .subscribe(
                onNext: { responses += [$0] },
                onCompleted: {
                    XCTAssert(cacheMisses == 2)
                    XCTAssert(responses.count == 3)
                    x.fulfill()
                }
            )
            .disposed(by: cleanup)
        
        waitForExpectations(timeout: 1.2)
    }
}
