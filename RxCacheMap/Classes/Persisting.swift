import RxSwift

public struct Persisting<Key, Value> {

    let set: (Value, Key) -> Void
    let value: (Key) -> Value?
    private let _reset: () -> Void

    public init<Backing>(
        backing: Backing,
        set: @escaping (Backing, Value, Key) -> Void,
        value: @escaping (Backing, Key) -> Value?,
        reset: @escaping (Backing) -> Void
    ) {
        self.set = {
            set(backing, $0, $1)
        }
        self.value = {
            value(backing, $0)
        }
        self._reset = {
            reset(backing)
        }
    }

    public func reset() {
        self._reset()
    }
}

extension Persisting {
    public static func nsCache<K, V>() -> Persisting<K, V> {
        return Persisting<K, V>(
            backing: NSCache<AnyObject, AnyObject>(),
            set: { cache, value, key in
                cache.setObject(
                    value as AnyObject,
                    forKey: key as AnyObject
                )
            },
            value: { cache, key in
                return cache
                    .object(forKey: key as AnyObject)
                    .flatMap { $0 as? V }
            },
            reset: { backing in
                backing.removeAllObjects()
            }
        )
    }

    public static func diskCache<K: Hashable, V: Codable>(id: String = "default") -> Persisting<K, Observable<V>> {
        Persisting<K, Observable<V>>(
            backing: (
                NSCache<AnyObject, AnyObject>(),
                URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.cachemap.rxswift.\(id)")
            ),
            set: { backing, value, key in
                let shared = value
                    .multicast(ReplaySubject.createUnbounded())
                    .refCount()
                backing.0.setObject(
                    Observable.merge(
                        shared,
                        shared
                            .reduce([V]()) { sum, next in sum + [next] }
                            .do(onNext: { next in
                                // SIDE-EFFECTS
                                try FileManager.default.createDirectory(at: backing.1, withIntermediateDirectories: true)
                                try JSONEncoder()
                                    .encode(next)
                                    .write(to: backing.1.appendingPathComponent("\(key)"))
                            })
                            .flatMap { _ in Observable<V>.empty() }
                    )
                    ,
                    forKey: key as AnyObject
                )
            },
            value: { backing, key in
                if let inMemory = backing.0.object(forKey: key as AnyObject) as? Observable<V> {
                    // 1. This one has disk write side-effect
                    return inMemory
                } else if let data = try? Data(contentsOf: backing.1.appendingPathComponent("\(key)")) {
                    // 2. Data is read back in ☝️
                    if let values = try? JSONDecoder().decode([V].self, from: data) {
                        let o = Observable.from(values)
                        // 3. Data is made an observable again but without the disk write side-effect
                        backing.0.setObject(o, forKey: key as AnyObject)
                        return o
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            },
            reset: { backing in
                backing.0.removeAllObjects()
                try? FileManager.default.removeItem(
                    at: backing.1
                )
            }
        )
    }

    public static func diskCache<K: Hashable & Codable, V: Codable>(id: String = "default") -> Persisting<K, V> {
        return Persisting<K, V>(
            backing: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.cachemap.rxswift.\(id)"),
            set: { folder, value, key in
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try JSONEncoder().encode(value).write(to: folder.appendingPathComponent("\(key)"))
                } catch {

                }
            },
            value: { folder, key in
                (try? Data(contentsOf: folder.appendingPathComponent("\(key)")))
                    .flatMap { data in try? JSONDecoder().decode(V.self, from: data) }
            },
            reset: { url in
                try? FileManager.default.removeItem(
                    at: url
                )
            }
        )
    }
}
