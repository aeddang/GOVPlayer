//
//  CustomResourceLoaderDelegate.swift
//  External WebVTT Example
//
//  Created by Joris Weimar on 24/01/2019.
//  Copyright © 2019 Joris Weimar. All rights reserved.
//
import Foundation
import AVFoundation
import Combine
extension GOVPlayer{
    class AssetResourceLoader: NSObject, @preconcurrency AVAssetResourceLoaderDelegate, GOVPlayerProtocol {
        static let scheme = "Asset"
        private let fragmentsScheme = "fragmentsm3u8"
        private var m3u8String: String? = nil
        private var originURL:URL? = nil
        private var baseURL:String? = nil
        private var delegate: GOVAssetPlayerDelegate?
        private var drm:FairPlayDrm? = nil
        private var info:AssetPlayerInfo? = nil
        private var keyProvider:AVContentKeyProvider? = nil
        init(m3u8URL: URL, playerDelegate:GOVAssetPlayerDelegate? = nil, keyProvider:AVContentKeyProvider? = nil, assetInfo:AssetPlayerInfo? = nil, drm:FairPlayDrm? = nil) {
            self.originURL = m3u8URL
            self.keyProvider = keyProvider
            if let drm = drm {
                self.drm = drm
            } else {
                if var components = URLComponents(string: m3u8URL.absoluteString) {
                    components.query = nil
                    self.baseURL = components.url?.deletingLastPathComponent().absoluteString ?? ""
                }
            }
            self.delegate = playerDelegate
            self.info = assetInfo
            super.init()
        }
        init( playerDelegate:GOVAssetPlayerDelegate? = nil) {
            self.delegate = playerDelegate
            super.init()
        }
        
        @MainActor
        func resourceLoader(
            _ resourceLoader: AVAssetResourceLoader,
            shouldWaitForLoadingOfRequestedResource
            loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
                self.redirectChecker?.cancel()
                if self.drm != nil {
                    return  handleRequest(loadingRequest)
                    
                    
                } else {
                    //DataLog.d("handleManifast none drm", tag: self.tag)
                    guard let path = loadingRequest.request.url?.absoluteString else { return false }
                    let originPath = path.hasPrefix(Self.scheme) ? path.replace(Self.scheme, with: "") : path
                    return handleManifast(loadingRequest, path:originPath)
                }
            }
        
        var redirectChecker:AnyCancellable?
        func redirectCheckStart(completion: @escaping () -> Void){
            self.redirectChecker?.cancel()
            DataLog.d("redirectCheck Start", tag: "CustomAssetPlayer")
            self.redirectChecker = Timer.publish(
                every: 3.0, on: .current, in: .common)
            .autoconnect()
            .sink() {_ in
                completion()
            }
        }
        
        
        @MainActor @discardableResult
        func getLicenseData(_ request: AVAssetResourceLoadingRequest, drmData:FairPlayDrm) -> Bool {
            guard let contentId = drmData.contentId else {
                let drmError:FairPlayError = .contentId(reason: "not found contentId")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
            
            if drmData.useOfflineKey {
                self.keyProvider?.request(contentId:contentId){ ckc, err, id in
                    if let drmError = err {
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.delegate?.onAssetLoadError(.drm(drmError))
                        request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                    } else if let ckcData = ckc {
                        self.drm?.isCompleted = true
                        self.delegate?.onAssetEvent(.keyReady(id, ckcData))
                    } else {
                        let drmError:FairPlayError = .ckcData(reason: "invalid ckc key")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.delegate?.onAssetLoadError(.drm(drmError))
                        request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                    }
                }
                return false
            }
            
            guard let certificate = drmData.certificate else {
                let drmError:FairPlayError = .certificate(reason: "not found certificate data")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
            
            guard let contentIdData = contentId.data(using:.utf8) else {
                let drmError:FairPlayError = .contentId(reason: "invalid contentId")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
            //DataLog.d("contentId " + contentId , tag: self.tag)
            //DataLog.d("contentIdData " + contentIdData.base64EncodedString() , tag: self.tag)
            
            
            
            guard let spcData = try? request.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: contentIdData, options:nil) else {
                let drmError:FairPlayError = .spcData(reason: "invalid spcData")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
            
            guard let ckcServer = URL(string: drmData.ckcURL) else {
                let drmError:FairPlayError = .ckcData(reason: "invalid license url")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                
                delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
            
            var licenseRequest = URLRequest(url: ckcServer)
            licenseRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            licenseRequest.httpMethod = "POST"
            var params = [String:String]()
            params["spc"] = spcData.base64EncodedString()
            params["assetId"] = contentId
            let body = params.map{$0.key + "=" + $0.value.toPercentEncoding()}.joined(separator: "&").data(using: .utf8)
            licenseRequest.httpBody = body
            /*
             if let body = body {
             DataLog.d("body " +  (String(data: body, encoding: .utf8) ?? "invalid data") , tag: self.tag)
             }*/
            
            let api: PlayerApi = .init(network: PlayerNetwork())
            api.getLicenseData(
                ckcUR: drmData.ckcURL, params: params,
                completion: {data in
                    guard let data = data else {
                        let drmError:FairPlayError = .ckcData(reason: "no ckcData")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.delegate?.onAssetLoadError(.drm(drmError))
                        request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                        return
                    }
                    
                    guard let responseString = String(data: data, encoding: .utf8) else {
                        let drmError:FairPlayError = .ckcData(reason: "invalid ckcData")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.delegate?.onAssetLoadError(.drm(drmError))
                        request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                        return
                    }
                    
                    let ckcKey = responseString
                        .replacingOccurrences(of:"\n<ckc>", with: "")
                        .replacingOccurrences(of:"</ckc>\n", with: "")
                        .replacingOccurrences(of: "<ckc>", with: "")
                        .replacingOccurrences(of: "</ckc>", with: "")
                    
                    
                    // DataLog.e("licenseData " + ckcKey, tag: self.tag)
                    if let ckcData = Data(base64Encoded:ckcKey) {
                        self.drm?.isCompleted = true
                        request.dataRequest?.respond(with:ckcData)
                        request.finishLoading()
                        // self.delegate?.onAssetEvent(.keyReady(nil, nil))
                        
                    } else {
                        let drmError:FairPlayError = .ckcData(reason: "invalid ckc key")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.delegate?.onAssetLoadError(.drm(drmError))
                        request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                    }
                },
                error: {_ in
                    let drmError:FairPlayError = .ckcData(reason: "connect error ckcData")
                    DataLog.e(drmError.getDescription(), tag: self.tag)
                    self.delegate?.onAssetLoadError(.drm(drmError))
                    request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                }
            )
            
            return true
        }
        
        @MainActor
        func handleRequest(_ request: AVAssetResourceLoadingRequest) -> Bool {
            if let drmData = self.drm {
                guard let assetIDString = request.request.url?.absoluteString.replace("skd://", with: "") else {
                    let drmError:FairPlayError = .contentId(reason: "no contentId")
                    DataLog.e(drmError.getDescription(), tag: self.tag)
                    self.delegate?.onAssetLoadError(.drm(drmError))
                    request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                    return false
                }
                if assetIDString.hasPrefix("http") {
                    drmData.contentId = request.request.url?.host
                } else {
                    drmData.contentId = assetIDString
                }
                //DataLog.d("handleRequest " +  (drmData.contentId ?? "nil"), tag: self.tag)
                return self.getLicenseData(request, drmData: drmData)
            } else {
                let drmError:FairPlayError = .stream
                DataLog.e(drmError.getDescription(), tag: self.tag)
                self.delegate?.onAssetLoadError(.drm(drmError))
                request.finishLoading(with:NSError(domain: drmError.getDomain(), code:drmError.getCode(), userInfo: nil))
                return false
            }
        }
        func handleManifast(path:String, completed: @escaping (AssetPlayerInfo?) -> Void ) {
            self.info = AssetPlayerInfo()
            self.handleManifast(nil, path: path, completed: completed)
        }
        @discardableResult
        func handleManifast(_ request: AVAssetResourceLoadingRequest?, path:String,
                            completed: ((AssetPlayerInfo?) -> Void)? = nil  ) -> Bool {
            
            if let prevInfo = self.info {
                self.info = prevInfo.copy()
            } else {
                self.info = AssetPlayerInfo()
            }
            
            guard let url = URL(string:path) else {
                completed?(self.info)
                return false
                
            }
            if let info = self.info {
                DataLog.d(info.selectedResolution ?? "auto" , tag:self.tag + " handleRequest")
                DataLog.d(info.selectedCaption ?? "auto"  , tag:self.tag + " handleRequest")
                DataLog.d(info.selectedAudio ?? "auto"  , tag:self.tag + " handleRequest")
            }
            let api: PlayerApi = .init(network: PlayerNetwork())
            api.handleManifast(
                path: path,
                completion: {data in
                    self.processPlaylistWithData(data ?? .init())
                    if let request = request {
                        self.finishRequestWithMainPlaylist(request)
                    }
                    if let info = self.info {
                        self.delegate?.onFindAllInfo(info)
                        completed?(info)
                    }
                },
                error: { error in
                    completed?(self.info)
                    request?.finishLoading(with: error)
                }
            )
            return true
        }
        
        func processPlaylistWithData(_ data: Data) {
            
            guard let string = String(data: data, encoding: .utf8) else { return }
            
            let lines = string.components(separatedBy: "\n")
            var newLines = [String]()
            var iterator = lines.makeIterator()
            var useLine = true
            while let line = iterator.next() {
                let customLine = modifyLine(line, useLine:useLine)
                if customLine.isEmpty {
                    useLine = false
                } else {
                    newLines.append(customLine)
                    useLine = true
                }
                
            }
            m3u8String = newLines.joined(separator: "\n")
            DataLog.d(m3u8String ?? "empty" , tag:self.tag + " m3u8String")
        }
        func modifyLine(_ line: String, useLine:Bool = true)-> String {
            
            let components = line.components(separatedBy: ":")
            if components.count < 2 {
                if let base  = self.baseURL {
                    line.hasSuffix(".m3u8")
                        ? (useLine ? base + line : "")
                        : line
                    DataLog.d("base " + base , tag:self.tag + " m3u8String")
                } else {
                    return line
                }
            }
            guard let key = components.first else { return line }
            let datas = components[1].components(separatedBy: ",")
            var isUnSelectedLine = false
            var newLine = datas.reduce(key+":", { pre, cur in
                let set = cur.components(separatedBy: "=")
                if set.count != 2 {return pre + cur + ","}
                let type = set[0]
                var value = set[1]
                value = value.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range:nil)
                switch type {
                case "URI":
                    if self.drm != nil {
                        return pre + cur  + ","
                    }
                    if let base = self.baseURL {
                        return pre + type + "=\"" + base + value  + "\","
                    } else {
                        return pre + cur  + ","
                    }
                    
                case "RESOLUTION":
                    self.info?.addResolution(value)
                    if let selValue = self.info?.selectedResolution {
                        if value != selValue { isUnSelectedLine = true }
                    }
                    return pre + cur  + ","
                case "CLOSED-CAPTIONS":  // SUBTITLES
                    self.info?.addCaption(value)
                    if let selValue = self.info?.selectedCaption {
                        if value != selValue { isUnSelectedLine = true }
                    }
                    return pre + cur  + ","
                case "AUDIO":
                    self.info?.addAudio(value)
                    if let selValue = self.info?.selectedAudio{
                        if value != selValue { isUnSelectedLine = true }
                    }
                    return pre + cur  + ","
                default : return pre + cur  + ","
                }
            })
            if !isUnSelectedLine {
                DataLog.d(newLine + " " + isUnSelectedLine.description , tag:self.tag + " newLine")
            }
            if isUnSelectedLine && newLine.hasPrefix("#EXT-X-STREAM-INF") {return ""}
            if newLine.last == "," { newLine.removeLast() }
            return newLine
        }
        
        func finishRequestWithMainPlaylist(_ request: AVAssetResourceLoadingRequest) {
            guard let data = self.m3u8String?.data(using: .utf8) else {
                let error:AssetLoadError = .parse(reason: "invalid m3u8String")
                DataLog.e(error.getDescription(), tag: self.tag)
                self.delegate?.onAssetLoadError(.asset(error))
                request.finishLoading(with:NSError(domain: error.getDomain(), code:error.getCode(), userInfo: nil))
                return
            }
            
            request.dataRequest?.respond(with: data)
            request.finishLoading()
            
        }
    }
}
