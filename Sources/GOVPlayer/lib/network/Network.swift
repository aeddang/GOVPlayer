//
//  Network.swift
//  ironright
//
//  Created by JeongCheol Kim on 2020/03/27.
//  Copyright © 2020 JeongCheol Kim. All rights reserved.
//

import Foundation
import Combine
import MobileCoreServices

typealias NetworkEnvironment = String
enum HTTPMethod: String {
    case get
    case post
    case put
    case patch
    case delete
}

enum APIMethod: String {
    case request
    case response
}

protocol NetworkRoute:GOVPlayerProtocol {
    var path: String { get }
    var method: HTTPMethod { get set }
    var headers: [String: String]? { get set }
    var overrideHeaders: [String: String]? { get set }
    var query: [String: String]? { get set }
    var body: [String: Any]? { get set }
    var bodys: [Any]? { get set }
    var postData: Data? { get set }
    var jsonString: String? { get set }
    var contentType:String? { get set }
    var withAllowedCharacters:CharacterSet? { get set }
    func onRequestIntercepter(request:URLRequest)
}

extension NetworkRoute {
    var headers: [String : String]?  { get{nil} set{headers=nil} }
    var overrideHeaders: [String : String]?  { get{nil} set{overrideHeaders=nil} }
    var query: [String: String]?  { get{nil} set{query=nil} }
    var body: [String: Any]?  { get{nil} set{body=nil} }
    var bodys: [Any]?  { get{nil} set{bodys=nil} }
    var postData: Data? { get{nil} set{postData=nil} }
    var contentType:String? { get{nil} set{contentType = nil} }
    var jsonString:String? { get{nil} set{jsonString = nil} }
    var withAllowedCharacters:CharacterSet? { get{.urlQueryAllowed} set{withAllowedCharacters = .urlQueryAllowed} }
    func create(for enviroment:NetworkEnvironment) -> URLRequest {
        let path = withAllowedCharacters == nil
            ? getURL(enviroment)
            : getURL(enviroment).addingPercentEncoding( withAllowedCharacters: withAllowedCharacters!)
        
        var request = URLRequest(url: URL(string:path!)!)
        if let type = contentType { request.addValue(type, forHTTPHeaderField: "Content-type") }
        else {  request.addValue("application/json", forHTTPHeaderField: "Content-type") }
        request.allHTTPHeaderFields = headers
        request.httpMethod = method.rawValue.uppercased()
        request.httpBody = getBody()

        //self.onRequestIntercepter(request: request)
        DataLog.d("request : " + request.debugDescription , tag:self.tag)
        return request
    }
    
    func create(for enviroment:NetworkEnvironment,
                multipartFormData constructingBlock: @escaping (_ formData: MultipartFormData) -> Void,
                encoding: String.Encoding = .utf8)  -> URLRequest
    {
        let path = getURL(enviroment).addingPercentEncoding( withAllowedCharacters: .urlQueryAllowed)
        var request = URLRequest(url: URL(string:path!)!)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method.rawValue.uppercased()
        request.httpBody = Data()
        //self.onRequestIntercepter(request: request)
        let formData = MultipartFormData(request: request, encoding:encoding)
        constructingBlock(formData)
        formData.finalize()
        //DataLog.d("request : " + request.debugDescription , tag:self.tag)
        return formData.request
    }
    func onRequestIntercepter(request:URLRequest){}
    
    private func getURL(_ enviroment:NetworkEnvironment) -> String{
        var base = enviroment + path
        if let params = query {
            if !params.isEmpty {
                var query = params.keys.reduce("", {
                    let v = params[$1] ?? ""
                    return $0 + "&" + $1 + "=" + v
                })
                query.removeFirst()
                let f = base.firstIndex(of: "?")
                base = (f == nil)
                    ? base + "?" + query
                    : base + "&" + query
            }
        }
        switch method {
        case .get:
            if let params = body {
                if params.isEmpty { return base }
                var query = params.keys.reduce("", {
                    let v = (params[$1] as? String ?? "")
                    return $0 + "&" + $1 + "=" + v
                })
                query.removeFirst()
                let f = base.firstIndex(of: "?")
                return f == nil
                    ? base + "?" + query
                    : base + "&" + query
            }
            else{
                return base
            }
        default:
            return base
        }
    }
    
    private func getBody() -> Data?{
        if method == .get {return nil}
        if let params = postData {
            return params
        }
        if let params = bodys {
            return try? JSONSerialization.data(withJSONObject:params)
        }
        if let params = jsonString {
            DataLog.d("jsonString : " + params, tag: self.tag)
            let data = params.data(using: .utf8)
            return data
        }
        
        guard let param = body else { return nil }
        if JSONSerialization.isValidJSONObject(param) {
            do{
                let data =  try JSONSerialization.data(withJSONObject: param , options: [])
                let jsonString = String(decoding: data, as: UTF8.self)
                DataLog.d("stringfy : " + jsonString, tag: self.tag)
                return jsonString.data(using: .utf8)
            } catch {
                DataLog.e("stringfy : JSONSerialization " + error.localizedDescription, tag: self.tag)
            }
        }
        
        DataLog.d("params : " + param.description , tag:self.tag)
        return try? JSONSerialization.data(withJSONObject:param)
    }
}

protocol Network:GOVPlayerProtocol {
    var decoder: JSONDecoder { get}
    var enviroment: NetworkEnvironment { get set }
    var encoding: String.Encoding { get }
    func onRequestIntercepter(request:URLRequest)->URLRequest
    func onDecodingError(data:Data, e:Error)->Error
}

extension Network {
    var decoder:JSONDecoder { get{ .init() } }
    var encoding: String.Encoding { get{ .utf8 } }
    
    private var sharedSession:URLSession  { get{ Rest.appURLSession } }
    
    func onRequestIntercepter(request:URLRequest)->URLRequest{return request}
    func onDecodingError(data:Data, e:Error)->Error{return e}
    func fetch<T: Decodable>(route: NetworkRoute) -> AnyPublisher<T, Error> {
        var request:URLRequest = route.create(for: enviroment)
        request = self.onRequestIntercepter(request: request)
        if let override =  route.overrideHeaders {
            override.forEach{ set in
                request.setValue(set.value, forHTTPHeaderField: set.key)
            }
        }
      
        self.debug(request: request)
        return self.sharedSession
            .dataTaskPublisher(for: request)
            .tryCompactMap { result in
            
                self.debug(data: result.data)
                do{
                    if T.Type.self == Blank.Type.self {
                        if !result.data.isEmpty {
                            throw self.onDecodingError(data: result.data, e:BlankError())
                        }else{
                            return Blank() as? T
                        }
                        
                    }else{
                         return try self.decoder.decode(T.self, from: result.data)
                    }
                   
                } catch {
                    throw self.onDecodingError(data: result.data, e: error)
                }
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func fetch<T: Decodable>(route: NetworkRoute,
                            multipartFormData constructingBlock: @escaping (_ formData: MultipartFormData) -> Void
    ) -> AnyPublisher<T, Error> {
        var request:URLRequest = route.create(for: enviroment, multipartFormData: constructingBlock, encoding: encoding)
        request = self.onRequestIntercepter(request: request)
        if let override =  route.overrideHeaders {
            override.forEach{ set in
                request.setValue(set.value, forHTTPHeaderField: set.key)
            }
        }
        self.debug(request: request)
       
        return self.sharedSession
            .dataTaskPublisher(for: request)
            .tryCompactMap { result in
                self.debug(data: result.data)
                do{
                    if T.Type.self == Blank.Type.self {
                        if !result.data.isEmpty {
                            throw self.onDecodingError(data: result.data, e:BlankError())
                        }else{
                            return Blank() as? T
                        }
                        
                    }else{
                         return try self.decoder.decode(T.self, from: result.data)
                    }
                } catch {
                    throw  self.onDecodingError(data: result.data, e: error)
                }
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    func fetch(route: NetworkRoute) -> AnyPublisher<[String : Any], Error> {
        var request:URLRequest = route.create(for: enviroment)
        request = self.onRequestIntercepter(request: request)
        if let override =  route.overrideHeaders {
            override.forEach{ set in
                request.setValue(set.value, forHTTPHeaderField: set.key)
            }
        }
        return self.sharedSession
            .dataTaskPublisher(for: request)
            .tryCompactMap { result in
                self.debug(data: result.data)
                do{
                    return try JSONSerialization.jsonObject(with: result.data, options: .init()) as? [String:Any]
                } catch {
                    throw self.onDecodingError(data: result.data, e: error)
                }
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    
    private func debug(request:URLRequest){
        #if DEBUG
        guard let headers = request.allHTTPHeaderFields else { return }
        let str = headers.reduce("headers :"){
            $0 + "\n" + $1.key + " : " + $1.value
        }
        DataLog.d(str, tag: self.tag)
        #endif
    }
    private func debug(data:Data?){
        #if DEBUG
        guard let data = data else {
            DataLog.d("no data", tag: self.tag)
            return
        }
        let str = String(decoding: data, as: UTF8.self)
        DataLog.d(str, tag: self.tag)
        
        #endif
    }
}


struct Blank:Decodable {}
struct BlankError:Error {}

class MultipartFormData {
    var request: URLRequest
    var encoding: String.Encoding
    private lazy var boundary: String = {
       return String(format: "%08X%08X", arc4random(), arc4random())
    }()
    
    init(request:URLRequest, encoding:String.Encoding) {
        self.request = request
        self.encoding = encoding
    }
    
    func append(value: String, name: String) {

        request.httpBody?.append("--\(boundary)\r\n".data(using: encoding)!)
        request.httpBody?.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: encoding)!)
        request.httpBody?.append( value.data(using: encoding)!)
        request.httpBody?.append("\r\n".data(using: encoding)!)
        
        let str = String(decoding: request.httpBody!, as: UTF8.self)
        DataLog.d(str)
    }
    
    
    func append(filePath: String, name: String) throws {
        let url = URL(fileURLWithPath: filePath)
        try append(fileUrl: url, name: name)
    }
    
    func append(fileUrl: URL, name: String) throws {
        let fileName = fileUrl.lastPathComponent
        let mimeType = contentType(for: fileUrl.pathExtension)
        try append(fileUrl: fileUrl, name: name, fileName: fileName, mimeType: mimeType)
    }
    
    func append(fileUrl: URL, name: String, fileName: String, mimeType: String) throws {
        let data = try Data(contentsOf: fileUrl)
        append(file: data, name: name, fileName: fileName, mimeType: mimeType)
    }
    
    func append(file: Data, name: String, fileName: String, mimeType: String) {
        request.httpBody?.append("--\(boundary)\r\n".data(using: encoding)!)
        request.httpBody?.append("Content-Disposition: form-data; name=\"\(name)\";".data(using: encoding)!)
        request.httpBody?.append("filename=\"\(fileName)\"\r\n".data(using: encoding)!)
        request.httpBody?.append("Content-Type: \(mimeType)\r\n\r\n".data(using: encoding)!)
        request.httpBody?.append(file)
        request.httpBody?.append("\r\n".data(using: encoding)!)
    }
    
    fileprivate func finalize() {
        request.httpBody?.append("--\(boundary)--\r\n".data(using: encoding)!)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let str = String(decoding: request.httpBody!, as: UTF8.self)
        DataLog.d(str)
    }
}

fileprivate func contentType(for pathExtension: String) -> String {
    guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue() else {
        return "application/octet-stream"
    }
    let contentTypeCString = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()
    guard let contentType = contentTypeCString as String? else {
        return "application/octet-stream"
    }
    return contentType
}
