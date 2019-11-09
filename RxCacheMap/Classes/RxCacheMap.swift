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
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
    ) -> Observable<T> {
        scan((
            cache: NSCache<AnyObject, AnyObject>(),
            key: Optional<Element>.none
        )) {(
            cache: Self.adding(
                key: $1 as AnyObject,
                value: input($1) as AnyObject,
                cache: reset($1) ? NSCache() : $0.cache
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
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
    ) -> Observable<T> {
        cachedReplay(
            observable: input,
            resettingWhen: reset
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
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
    ) -> Observable<T> {
        cachedReplay(
            observable: input,
            resettingWhen: reset
        )
        .flatMapLatest { $0 }
    }
    
    private func cachedReplay<T>(
        observable input: @escaping (Element) -> Observable<T>,
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
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
                cache: reset($1) ? NSCache() : $0.cache
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
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
    ) -> Observable<T> {
        cachedReplayUntilExpired(
            observable: input,
            resettingWhen: reset
        )
        .flatMap { $0 }
    }
    
    private func cachedReplayUntilExpired<T>(
        observable input: @escaping (Element) -> Observable<(T, Date)>,
        resettingWhen reset: @escaping (Element) -> Bool = { _ in false }
    ) -> Observable<Observable<T>> {
        scan((
            cache: NSCache<AnyObject, Observable<T>>(),
            key: Optional<Element>.none
        )) { sum, new in (
            cache: Self.adding(
                key: new as AnyObject,
                value: Self.replayingUntilExpired(
                    input: input,
                    key: new
                ),
                cache: reset(new) ? NSCache() : sum.cache
            ),
            key: new
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
