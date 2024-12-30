//
//  Api.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/31/24.
//
import Foundation
import GOLibrary
extension GOVPlayer{
    class PlayerApi: Rest{
        func getLicenseData(ckcUR: String, params: [String : Any],
                            completion: @escaping (Data?) -> Void, error: ((_ e:Error) -> Void)? = nil) {
            fetch(route: PlayerRoute(method: .post, path: ckcUR, body: params) ,
                  completion: completion, error:error)
        }
        func handleManifast(path:String,
                            completion: @escaping (Data?) -> Void, error: ((_ e:Error) -> Void)? = nil) {
            fetch(route: PlayerRoute(method: .get, path: path) ,
                  completion: completion, error:error)
        }
    }
    struct PlayerNetwork : Network{
        var enviroment: NetworkEnvironment = ""
        func onRequestIntercepter(request: URLRequest) -> URLRequest {
            return request
        }
    }
    struct PlayerRoute: NetworkRoute {
        var method: HTTPMethod = .get
        var path: String = ""
        var body: [String : Any]? = nil
        var query: [String : String]? = nil
    }
}
