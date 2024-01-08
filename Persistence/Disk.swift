import RxSwift
import CryptoKit

extension Persisting {
    public static func diskCache<K: Codable, V: Codable>(id: String = "default") -> Persisting<K, Observable<V>> {
        Persisting<K, Observable<V>>(
            backing: (
                writes: TypedCache<String, Observable<V>>(),
                memory: TypedCache<String, Observable<V>>(),
                disk: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.cachemap.rxswift.\(id)")
            ),
            set: { backing, value, key in
                let key = try! Persisting.sha256Hash(for: key) // TODO: Revisit force unwrap
                let shared = value
                    .multicast(ReplaySubject.createUnbounded())
                    .refCount()
                backing.writes.setObject(
                    Observable.merge(
                        shared,
                        shared
                            .materialize()
                            .toArray()
                            .asObservable()
                            .do(onNext: { next in
                                // SIDE-EFFECTS
                                try FileManager.default.createDirectory(at: backing.disk, withIntermediateDirectories: true)
                                try JSONEncoder()
                                    .encode(next.map(WrappedEvent.init(event:)))
                                    .write(to: backing.disk.appendingPathComponent("\(key)"))
                            })
                            .flatMap { _ in Observable<V>.empty() }
                    )
                    ,
                    forKey: key
                )
            },
            value: { backing, key in
                let key = try! Persisting.sha256Hash(for: key) // TODO: Revisit force unwrap
                if let write = backing.writes.object(forKey: key) {
                    // 1. This write-observable has disk write side-effect. Next access will trigger disk read
                    backing.writes.removeObject(forKey: key) // SIDE-EFFECT
                    return write
                } else if let memory = backing.memory.object(forKey: key) {
                    // 4. Further gets come from memory
                    return memory
                } else if let data = try? Data(contentsOf: backing.disk.appendingPathComponent("\(key)")) {
                    // 2. Data is read back in ☝️
                    if let values = try? JSONDecoder().decode([WrappedEvent<V>].self, from: data) {
                        let o = Observable.observable(from: values)
                        // 3. Data is made an observable again but without the disk write side-effect
                        backing.memory.setObject(o, forKey: key)
                        return o
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            },
            reset: { backing in
                backing.memory.removeAllObjects()
                try? FileManager.default.removeItem(
                    at: backing.disk
                )
            }
        )
    }

    public static func diskCache<K: Hashable, V: Codable>(id: String = "default") -> Persisting<K, V> {
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

    private static func sha256Hash<T: Codable>(for data: T) throws -> String {
        SHA256
            .hash(data: try JSONEncoder().encode(data))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

private struct WrappedEvent<T: Codable>: Codable {
    let event: RxSwift.Event<T>

    // Custom Error to handle non-codable errors
    private struct CodableError: Error, Codable {
        let message: String
        init(error: Error) {
            self.message = error.localizedDescription
        }
        init(message: String) {
            self.message = message
        }
    }

    enum CodingKeys: String, CodingKey {
        case next, error, completed
    }

    init(event: RxSwift.Event<T>) {
        self.event = event
    }

    // Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(T.self, forKey: .next) {
            self.event = .next(value)
        } else if let message = try container.decodeIfPresent(String.self, forKey: .error) {
            self.event = .error(CodableError(message: message))
        } else if container.contains(.completed) {
            self.event = .completed
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Decoding WrappedEvent failed"))
        }
    }

    // Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch event {
        case .next(let value):
            try container.encode(value, forKey: .next)
        case .error(let error):
            let errorMessage = (error as? CodableError)?.message ?? error.localizedDescription
            try container.encode(errorMessage, forKey: .error)
        case .completed:
            try container.encode(true, forKey: .completed)
        }
    }
}

fileprivate extension Observable {
    static func observable(from wrappedEvents: [WrappedEvent<Element>]) -> Observable<Element> where Element: Decodable {
        return Observable.create { observer in
            for wrappedEvent in wrappedEvents {
                switch wrappedEvent.event {
                case .next(let value):
                    observer.onNext(value)
                case .error(let error):
                    observer.onError(error)
                    return Disposables.create()
                case .completed:
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
            return Disposables.create()
        }
    }
}

// Testing
public func persistToDisk<K: Hashable, V: Codable>(key: K, item: Observable<V>) {
    _ = item
    .materialize()
    .toArray()
    .asObservable()
    .do(onNext: { next in
        // SIDE-EFFECTS
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.cachemap.rxswift.default"),
            withIntermediateDirectories: true
        )
        try JSONEncoder()
            .encode(next.map(WrappedEvent.init(event:)))
            .write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.cachemap.rxswift.default").appendingPathComponent("\(key)"))
    })
    .subscribe()
}
