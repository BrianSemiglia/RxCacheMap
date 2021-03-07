import RxSwift

extension ObservableType where Element: Hashable {
    
    /**
    Caches events and replays when latest incoming value equals a previous and the execution of the map took more time than the specified duration else produces new events.
    */

    public func cacheMap<T>(
        whenExceeding duration: DispatchTimeInterval,
        cache: Persisting<Element, T> = .nsCache(),
        input: @escaping (Element) -> T
    ) -> Observable<T> {
        return scan((
            cache: cache,
            key: Optional<Element>.none,
            value: Optional<T>.none
        )) {
            if let _ = $0.cache.value($1) {
                return (
                    cache: $0.cache,
                    key: $1,
                    value: nil
                )
            } else {
                let start = Date()
                let result = input($1)
                let end = Date()
                if duration.seconds.map({ end.timeIntervalSince(start) > $0 }) == true {
                    return (
                        cache: Self.adding(
                            key: $1,
                            value: result,
                            cache: $0.cache
                        ),
                        key: $1,
                        value: nil
                    )
                } else {
                    return (
                        cache: $0.cache,
                        key: nil,
                        value: result
                    )
                }
            }
        }
        .map { tuple in
            tuple.value ??
            tuple.key.flatMap { tuple.cache.value($0) }
        }
        .flatMap {
            $0.map(Observable.just) ??
            .never()
        }
    }
    
    /**
     Caches events and replays when latest incoming value equals a previous else produces new events.
     */
    public func cacheMap<T>(
        cache: Persisting<Element, T> = .nsCache(),
        when condition: @escaping (Element) -> Bool = { _ in true },
        transform: @escaping (Element) -> T
    ) -> Observable<T> {
        return scan((
            cache: cache,
            key: Optional<Element>.none,
            value: Optional<T>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1,
                value: transform($1),
                cache: $0.cache
            ),
            key: $1,
            value: condition($1) ? nil : transform($1)
        )}
        .map { tuple in
            tuple.value ??
            tuple.key.flatMap { tuple.cache.value($0) }
        }
        .flatMap {
            $0.map(Observable.just) ??
            .never()
        }
    }
    
    /**
     Caches observables and replays their events when latest incoming value equals a previous else produces new events.
     */
    public func cacheFlatMap<T>(
        cache: Persisting<Element, Observable<T>> = .nsCache(),
        when condition: @escaping (Element) -> Bool = { _ in true },
        observable input: @escaping (Element) -> Observable<T>
    ) -> Observable<T> {
        return cachedReplay(
            cache: cache,
            when: condition,
            observable: input
        )
        .flatMap { $0 }
    }
    
    /**
     Caches completed observables and replays their events when latest incoming value equals a previous else produces new events.
     Cancels playback of previous observables.
     */
    public func cacheFlatMapLatest<T>(
        cache: Persisting<Element, Observable<T>> = .nsCache(),
        when condition: @escaping (Element) -> Bool = { _ in true },
        observable input: @escaping (Element) -> Observable<T>
    ) -> Observable<T> {
        return cachedReplay(
            cache: cache,
            when: condition,
            observable: input
        )
        .flatMapLatest { $0 }
    }
    
    private func cachedReplay<T>(
        cache: Persisting<Element, Observable<T>>,
        when condition: @escaping (Element) -> Bool = { _ in true },
        observable input: @escaping (Element) -> Observable<T>
    ) -> Observable<Observable<T>> {
        return scan((
            cache: cache,
            key: Optional<Element>.none,
            value: Optional<Observable<T>>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1,
                value: input($1)
                    .multicast(ReplaySubject.createUnbounded())
                    .refCount()
                ,
                cache: $0.cache
            ),
            key: $1,
            value: condition($1) ? nil : input($1)
        )}
        .map { tuple in
            tuple.value ??
            tuple.key.flatMap { tuple.cache.value($0) }
            ?? .never()
        }
    }
    
    /**
     Caches observables and replays their events when latest incoming value equals a previous value and output Date is greater than Date of event else produces new events.
     */
    public func cacheFlatMapInvalidatingOn<T>(
        when condition: @escaping (Element) -> Bool = { _ in true },
        cache: Persisting<Element, Observable<T>> = .nsCache(),
        observable input: @escaping (Element) -> Observable<(T, Date)>
    ) -> Observable<T> {
        return cachedReplayInvalidatingOn(
            when: condition,
            cache: cache,
            observable: input
        )
        .flatMap { $0 }
    }
    
    private func cachedReplayInvalidatingOn<T>(
        when condition: @escaping (Element) -> Bool = { _ in true },
        cache: Persisting<Element, Observable<T>>,
        observable input: @escaping (Element) -> Observable<(T, Date)>
    ) -> Observable<Observable<T>> {
        return scan((
            cache: cache,
            key: Optional<Element>.none,
            value: Optional<Observable<T>>.none
        )) {(
            cache: condition($1) == false ? $0.cache : Self.adding(
                key: $1,
                value: Self.replayingInvalidatingOn(
                    input: input($1)
                ),
                cache: $0.cache
            ),
            key: $1,
            value: condition($1) ? nil : input($1).map { $0.0 }
        )}
        .map { tuple in
            tuple.value ??
            tuple.key.flatMap { tuple.cache.value($0) } ??
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
    
    private static func adding<Key, Value>(
        key: Key,
        value: @autoclosure () -> Value,
        cache: Persisting<Key, Value>
    ) -> Persisting<Key, Value> {
        if cache.value(key) == nil {
            cache.set(
                value(),
                key
            )
            return cache
        } else {
            return cache
        }
    }
}

extension DispatchTimeInterval {
    var seconds: Double? {
        switch self {
        case .seconds(let value):
            return Double(value)
        case .milliseconds(let value):
            return Double(value) * 0.001
        case .microseconds(let value):
            return Double(value) * 0.000001
        case .nanoseconds(let value):
            return Double(value) * 0.000000001
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }
}
