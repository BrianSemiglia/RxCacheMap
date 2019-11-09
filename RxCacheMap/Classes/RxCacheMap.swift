import RxSwift

extension ObservableType where Element: Hashable {
    
    public func cacheMap<T>(
        _ input: @escaping (Element) -> T
    ) -> Observable<T> {
        cacheMap(transform: input)
    }
    
    /**
     Caches events and replays when latest incoming value equals a previous else produces new events.
     */
    public func cacheMap<T>(
        transform input: @escaping (Element) -> T,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        scan((
            cache: NSCache<AnyObject, AnyObject>(),
            key: Optional<Element>.none
        )) {(
            cache: Self.adding(
                key: $1 as AnyObject,
                value: input($1) as AnyObject,
                cache: condition($1) ? $0.cache : NSCache()
            ),
            key: $1
        )}
        .map { $0.cache.object(forKey: $0.key as AnyObject) as? T }
        .flatMap { $0.map(Observable.just) ?? Observable.never() }
    }
    
    public func cacheFlatMap<T>(
        _ input: @escaping (Element) -> Observable<T>
    ) -> Observable<T> {
        cacheFlatMap(observable: input)
    }
    
    /**
     Caches observables and replays their events when latest incoming value equals a previous else produces new events.
     */
    public func cacheFlatMap<T>(
        observable input: @escaping (Element) -> Observable<T>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        cachedReplay(
            observable: input,
            when: condition
        )
        .flatMap { $0 }
    }
    
    public func cacheFlatMapLatest<T>(
        _ input: @escaping (Element) -> Observable<T>
    ) -> Observable<T> {
        cacheFlatMapLatest(observable: input)
    }
    
    /**
     Caches completed observables and replays their events when latest incoming value equals a previous else produces new events.
     Cancels playback of previous observables.
     */
    public func cacheFlatMapLatest<T>(
        observable input: @escaping (Element) -> Observable<T>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        cachedReplay(
            observable: input,
            when: condition
        )
        .flatMapLatest { $0 }
    }
    
    private func cachedReplay<T>(
        observable input: @escaping (Element) -> Observable<T>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<Observable<T>> {
        scan((
            cache: NSCache<AnyObject, Observable<T>>(),
            key: Optional<Element>.none
        )) {(
            cache: Self.adding(
                key: $1 as AnyObject,
                value: input($1)
                    .multicast(ReplaySubject.createUnbounded())
                    .refCount()
                ,
                cache: condition($1) ? $0.cache : NSCache()
            ),
            key: $1
        )}
        .map {
            $0.cache.object(forKey: $0.key as AnyObject)
            ?? .never()
        }
    }
    
    public func cacheFlatMapUntilExpired<T>(
        _ input: @escaping (Element) -> Observable<(T, Date)>
    ) -> Observable<T> {
        cacheFlatMapUntilExpired(observable: input)
    }
    
    /**
     Caches observables and replays their events when latest incoming value equals a previous value and output Date is greater than Date of event else produces new events.
     */
    public func cacheFlatMapUntilExpired<T>(
        observable input: @escaping (Element) -> Observable<(T, Date)>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        cachedReplayUntilExpired(
            observable: input,
            when: condition
        )
        .flatMap { $0 }
    }
    
    private func cachedReplayUntilExpired<T>(
        observable input: @escaping (Element) -> Observable<(T, Date)>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<Observable<T>> {
        scan((
            cache: NSCache<AnyObject, Observable<T>>(),
            key: Optional<Element>.none
        )) {(
            cache: Self.adding(
                key: $1 as AnyObject,
                value: Self.replayingUntilExpired(
                    input: input,
                    key: $1
                ),
                cache: condition($1) ? $0.cache : NSCache()
            ),
            key: $1
        )}
        .map {
            $0.cache.object(forKey: $0.key as AnyObject)
            ?? .never()
        }
    }
    
    private static func replayingUntilExpired<T, U>(
        input: @escaping (U) -> Observable<(T, Date)>,
        key: U
    ) -> Observable<T> {
        let now = { Date() }
        return input(key)
            .multicast(ReplaySubject.createUnbounded())
            .refCount()
            .flatMap { new, expiration in
                expiration >= now()
                    ? Observable.just(new)
                    : replayingUntilExpired(input: input, key: key)
            }
    }
    
    private static func adding<T, U>(
        key: T,
        value: @autoclosure () -> U,
        cache: NSCache<T, U>
    ) -> NSCache<T, U> {
        if cache.object(forKey: key) == nil {
            cache.setObject(
                value(),
                forKey: key
            )
            return cache
        } else {
            return cache
        }
    }
}
