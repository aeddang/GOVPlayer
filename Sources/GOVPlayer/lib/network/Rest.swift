//
//  ApiManager.swift
//  shoppingTrip
//
//  Created by JeongCheol Kim on 2020/07/31.
//  Copyright © 2020 JeongCheol Kim. All rights reserved.
//

import Foundation
import Combine



open class Rest :GOVPlayerProtocol{
    static let appURLSession:URLSession = .init(configuration: .default)
    let network:Network
    private var anyCancellable = Set<AnyCancellable>()
    
    init(network:Network) {
        self.network = network
    }
    
    func clear(){
        anyCancellable.forEach{
            $0.cancel()
        }
        anyCancellable.removeAll()
    }
    
    func fetch<T: Decodable>(
        route:NetworkRoute,
        completion: @escaping (T) -> Void,
        error: ((_ e:Error) -> Void)? = nil)
    {
        network.fetch(route: route)
        .mapError( { e -> Error in
            DataLog.e("error : \(e)", tag: self.tag) 
            return e
        })
        .sink(receiveCompletion: { result in
            guard let err = error else { return }
            switch result{
                case .finished: break
                case .failure(let e): err(e)
            }
        },receiveValue: { value in
            completion(value)
        })
        .store(in: &anyCancellable)
    }
    
    func fetch<T: Decodable>(
        route:NetworkRoute,
        constructingBlock: @escaping (_ formData: MultipartFormData) -> Void,
        completion: @escaping (T) -> Void,
        error: ((_ e:Error) -> Void)? = nil)
    {
        network.fetch(route: route, multipartFormData:constructingBlock)
        .mapError( { e -> Error in
            DataLog.e("error : \(e)", tag: self.tag)
            return e
        })
        .sink(receiveCompletion: { result in
            guard let err = error else { return }
            switch result{
                case .finished: break
                case .failure(let e): err(e)
            }
        },receiveValue: { value in
            completion(value)
        })
        .store(in: &anyCancellable)
    }
    
    func fetch(
        route:NetworkRoute,
        completion: @escaping ([String:Any]) -> Void,
        error: ((_ e:Error) -> Void)? = nil)
    {
        network.fetch(route: route)
        .mapError( { e -> Error in
            DataLog.e("error : \(e)", tag: self.tag)
            return e
        })
        .sink(receiveCompletion: { result in
            guard let err = error else { return }
            switch result{
                case .finished: break
                case .failure(let e): err(e)
            }
        },receiveValue: { value in
            completion(value)
        })
        .store(in: &anyCancellable)
    }
}
