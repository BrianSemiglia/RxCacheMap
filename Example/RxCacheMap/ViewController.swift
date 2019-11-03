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
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .userInteractive))
            .cacheFlatMapLatest {
                Observable
                    .just($0)
                    .unwrap()
                    .unwrapMap { $0.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) }
                    .unwrapMap { URL(string: "https://en.wikipedia.org/?search=" + $0) }
                    .map       { URLRequest(url: $0) }
                    .flatMap   (URLSession.shared.rx.response)
                    .unwrapMap {
                        try? NSAttributedString(
                            data: $0.data,
                            options: [.documentType: NSAttributedString.DocumentType.html],
                            documentAttributes: nil
                        )
                    }
            }
            .observeOn(MainScheduler.instance)
            .bind(to: output.rx.attributedText)
            .disposed(by: cleanup)
    }
    
}

extension ObservableType {
    public func unwrap<T>() -> Observable<T> where Element == T? {
        flatMap { $0.map(Observable.just) ?? .never() }
    }
    func unwrapMap<U>(_ f: @escaping (Element) -> U?) -> Observable<U> {
        map(f).unwrap()
    }
}

