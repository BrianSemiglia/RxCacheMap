extension Persisting {
    public static func nsCache<K, V>() -> Persisting<K, V> {
        return Persisting<K, V>(
            backing: TypedCache<K, V>(),
            set: { cache, value, key in
                cache.setObject(
                    value,
                    forKey: key
                )
            },
            value: { cache, key in
                cache.object(forKey: key)
            },
            reset: { backing in
                backing.removeAllObjects()
            }
        )
    }
}
