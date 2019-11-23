public struct Persisting<Key, Value> {

    let set: (Value, Key) -> Void
    let value: (Key) -> Value?

    public init<Backing>(
        backing: Backing,
        set: @escaping (Backing, Value, Key) -> Void,
        value: @escaping (Backing, Key) -> Value?
    ) {
        self.set = {
            set(backing, $0, $1)
        }
        self.value = {
            value(backing, $0)
        }
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
                cache
                    .object(forKey: key as AnyObject)
                    .flatMap { $0 as? V }
            }
        )
    }
}
