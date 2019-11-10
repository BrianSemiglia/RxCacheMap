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
        transform: @escaping (Element) -> T,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        scan((
            cache: NSCache<AnyObject, AnyObject>(),
            key: Optional<Element>.none,
            value: Optional<T>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1 as AnyObject,
                value: transform($1) as AnyObject,
                cache: $0.cache
            ),
            key: $1,
            value: condition($1)
                ? nil
                : transform($1)
        )}
        .map {
            $0.value ??
            $0.cache.object(forKey: $0.key as AnyObject) as? T
        }
        .flatMap { $0.map(Observable.just) ?? .never() }
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
            key: Optional<Element>.none,
            value: Optional<Observable<T>>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1 as AnyObject,
                value: input($1)
                    .multicast(ReplaySubject.createUnbounded())
                    .refCount()
                ,
                cache: condition($1) ? $0.cache : NSCache()
            ),
            key: $1,
            value: condition($1) ? nil : input($1)
        )}
        .map {
            $0.value ??
            $0.cache.object(forKey: $0.key as AnyObject)
            ?? .never()
        }
    }
    
    public func cacheFlatMapInvalidatingOn<T>(
        _ input: @escaping (Element) -> Observable<(T, Date)>
    ) -> Observable<T> {
        cacheFlatMapInvalidatingOn(observable: input)
    }
    
    /**
     Caches observables and replays their events when latest incoming value equals a previous value and output Date is greater than Date of event else produces new events.
     */
    public func cacheFlatMapInvalidatingOn<T>(
        observable input: @escaping (Element) -> Observable<(T, Date)>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<T> {
        cachedReplayInvalidatingOn(
            observable: input,
            when: condition
        )
        .flatMap { $0 }
    }
    
    private func cachedReplayInvalidatingOn<T>(
        observable input: @escaping (Element) -> Observable<(T, Date)>,
        when condition: @escaping (Element) -> Bool = { _ in true }
    ) -> Observable<Observable<T>> {
        scan((
            cache: NSCache<AnyObject, Observable<T>>(),
            key: Optional<Element>.none,
            value: Optional<Observable<T>>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1 as AnyObject,
                value: Self.replayingInvalidatingOn(
                    input: input($1)
                ),
                cache: $0.cache
            ),
            key: $1,
            value: condition($1) ? nil : input($1).map { $0.0 }
        )}
        .map {
            $0.value ??
            $0.cache.object(forKey: $0.key as AnyObject) ??
            .never()
        }
    }
    
    private static func replayingInvalidatingOn<T>(
        input: Observable<(T, Date)>
    ) -> Observable<T> {
        let now = { Date() }
        return input
            .multicast(ReplaySubject.createUnbounded())
            .refCount()
            .flatMap { new, expiration in
                expiration >= now()
                    ? Observable.just(new)
                    : replayingInvalidatingOn(
                        input: input
                    )
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
