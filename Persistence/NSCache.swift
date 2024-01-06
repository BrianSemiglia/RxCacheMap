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
}
