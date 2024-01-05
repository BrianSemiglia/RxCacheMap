//
//  ViewController.swift
//  RxCacheMap
//
//  Created by brian.semiglia@gmail.com on 01/31/2019.
//  Copyright (c) 2019 brian.semiglia@gmail.com. All rights reserved.
//

import UIKit
import RxCacheMap
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    
    private let cleanup = DisposeBag()
    @IBOutlet private var input: UISearchBar!
    @IBOutlet private var output: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        input
            .rx
            .text
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInteractive))
            .cacheFlatMapLatest(cache: .diskCache()) { x -> Observable<AttributedString?> in
                Observable
                    .just(x)
                    .compact()
                    .compactMap { $0.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) }
                    .compactMap { URL(string: "https://en.wikipedia.org/?search=" + $0) }
                    .map       { URLRequest(url: $0) }
                    .flatMap   (URLSession.shared.rx.response)
                    .compactMap {
                        try? NSAttributedString(
                            data: $0.data,
                            options: [.documentType: NSAttributedString.DocumentType.html],
                            documentAttributes: nil
                        )
                    }
                    .map { AttributedString(nsAttributedString: $0) }
            }
            .compactMap { $0?.attributedString }
            .observe(on: MainScheduler.instance)
            .bind(to: output.rx.attributedText)
            .disposed(by: cleanup)
    }
    
}

extension ObservableType {
    public func compact<T>() -> Observable<T> where Element == T? {
        return flatMap { $0.map(Observable.just) ?? .never() }
    }
    func compactMap<U>(_ f: @escaping (Element) -> U?) -> Observable<U> {
        return map(f).compact()
    }
}

class AttributedString : Codable {

    let attributedString : NSAttributedString

    init(nsAttributedString : NSAttributedString) {
        self.attributedString = nsAttributedString
    }

    public required init(from decoder: Decoder) throws {
        let singleContainer = try decoder.singleValueContainer()
        guard let attributedString = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: singleContainer.decode(Data.self)) else {
            throw DecodingError.dataCorruptedError(in: singleContainer, debugDescription: "Data is corrupted")
        }
        self.attributedString = attributedString
    }

    public func encode(to encoder: Encoder) throws {
        var singleContainer = encoder.singleValueContainer()
        try singleContainer.encode(NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false))
    }
}
