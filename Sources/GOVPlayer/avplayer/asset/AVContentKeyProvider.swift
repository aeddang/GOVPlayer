//
//  key.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//
import Foundation
import AVKit
import SwiftUI
import GOLibrary
extension GOVPlayer{

    
    final class AVContentKeyProvider:NSObject, AVContentKeySessionDelegate, GOVPlayerProtocol {
        
        @MainActor private var licenseData:Data? = nil
        @MainActor private var ckcURL:String = ""
        @MainActor private var session:AVContentKeySession? = nil
        @MainActor private var prevPersistableContentKey:[String:Data] = [:]
        @MainActor var complete:((Data?, FairPlayError?, String) -> Void)? = nil
        
        override init() {
            super.init()
            #if targetEnvironment(simulator)
            // your simulator code
            #else
                self.session = AVContentKeySession(keySystem: .fairPlayStreaming)
                self.session?.setDelegate(self, queue: .global(qos: .background))
            #endif
        }
        
        @MainActor func bind(asset:AVURLAsset, drm:FairPlayDrm, completed: ((Data?, FairPlayError?, String) -> Void)? = nil)  {
            self.complete = completed
            if let cert = drm.certificate{
                self.licenseData = cert
            }
            if !drm.ckcURL.isEmpty {
                self.ckcURL = drm.ckcURL
            }
            //asset.resourceLoader.preloadsEligibleContentKeys = true
            self.session?.addContentKeyRecipient(asset)
        }
        
        
        @MainActor func request(contentId:String, completed: ((Data?, FairPlayError?, String) -> Void)? = nil)  {
            self.complete = completed
        }
        
        @MainActor func addContentKey(contentId:String, key:Data, date:Date?){
            self.prevPersistableContentKey[contentId] = key
        }
        
        
        func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
            DataLog.d("didProvide AVContentKey", tag: self.tag)
            DispatchQueue.global(qos: .background).async{ [weak self] in
                guard let self = self else { return }
                if !keyRequest.canProvidePersistableContentKey {
                    do {
                        try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
                    }
                    catch {
                        DataLog.e(error.localizedDescription, tag: self.tag)
                    }
                }
            }
        }
        
        func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
            DataLog.d("didProvideRenewingContentKeyRequest", tag: self.tag)
        }
        
        func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVPersistableContentKeyRequest) {
            DispatchQueue.global(qos: .background).async{ [weak self] in
                guard let self = self else { return }
                DataLog.d("didProvide PersistableContentKey", tag: self.tag)
                guard let contentKeyIdentifierString = keyRequest.identifier as? String,
                      let contentIdentifier = contentKeyIdentifierString.replacingOccurrences(of: "skd://", with: "") as String?,
                      let contentIdentifierData = contentIdentifier.data(using: .utf8) else {
                    let drmError:FairPlayError = .contentId(reason: "not found contentId")
                    DataLog.e(drmError.getDescription(), tag: self.tag)
                    DispatchQueue.main.async{
                        self.complete?(nil, drmError, "")
                    }
                    return
                }
                DispatchQueue.main.async{
                    if let prevKey = self.prevPersistableContentKey[contentIdentifier] {
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: prevKey)
                        keyRequest.processContentKeyResponse(keyResponse)
                        return
                    }
                    
                    
                    guard let certificate = self.licenseData else {
                        let drmError:FairPlayError = .certificate(reason: "not found certificate data")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.complete?(nil, drmError, contentIdentifier)
                        return
                    }
                    guard let ckcServer = URL(string: self.ckcURL) else {
                        let drmError:FairPlayError = .ckcData(reason: "invalid license url")
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        self.complete?(nil, drmError, contentIdentifier)
                        return
                    }
                    //guard let complete = self.complete else {return}
                    keyRequest.makeStreamingContentKeyRequestData(
                        forApp: certificate, contentIdentifier: contentIdentifierData,
                        options: nil){ [weak self] spcData, error in
                            guard let self = self else { return }
                            guard let spcData = spcData else {
                                let drmError:FairPlayError = .ckcData(reason: "no spcData")
                                DataLog.e(drmError.getDescription(), tag: self.tag)
                                DispatchQueue.main.async{
                                    self.complete?(nil, drmError, contentIdentifier)
                                }
                                return
                            }
                            
                            var licenseRequest = URLRequest(url: ckcServer)
                            licenseRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                            licenseRequest.httpMethod = "POST"
                            var params = [String:String]()
                            params["spc"] = spcData.base64EncodedString()
                            params["assetId"] = contentIdentifier
                            let body = params.map{$0.key + "=" + $0.value.toPercentEncoding()}.joined(separator: "&").data(using: .utf8)
                            licenseRequest.httpBody = body
                            /*
                             if let body = body {
                             DataLog.d("body " +  (String(data: body, encoding: .utf8) ?? "invalid data") , tag: self.tag)
                             }
                             */
                            let task = URLSession.shared.dataTask(with: licenseRequest) { [weak self] data, response, error in
                                guard let self = self else { return }
                                guard let data = data else {
                                    let drmError:FairPlayError = .ckcData(reason: "no ckcData")
                                    DataLog.e(drmError.getDescription(), tag: self.tag)
                                    DispatchQueue.main.async{
                                        self.complete?(nil, drmError, contentIdentifier)
                                    }
                                    return
                                }
                                
                                guard let responseString = String(data: data, encoding: .utf8) else {
                                    let drmError:FairPlayError = .ckcData(reason: "invalid ckcData")
                                    DataLog.e(drmError.getDescription(), tag: self.tag)
                                    DispatchQueue.main.async{
                                        self.complete?(nil, drmError, contentIdentifier)
                                    }
                                    return
                                }
                                
                                let ckcKey = responseString
                                    .replacingOccurrences(of:"\n<ckc>", with: "")
                                    .replacingOccurrences(of:"</ckc>\n", with: "")
                                    .replacingOccurrences(of: "<ckc>", with: "")
                                    .replacingOccurrences(of: "</ckc>", with: "")
                                
                                
                                
                                if let ckcData = Data(base64Encoded:ckcKey) {
                                    if let persistableContentKey = try? keyRequest.persistableContentKey(fromKeyVendorResponse: ckcData) {
                                        DispatchQueue.main.async{
                                            self.prevPersistableContentKey[contentIdentifier] = persistableContentKey
                                            let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: persistableContentKey)
                                            keyRequest.processContentKeyResponse(keyResponse)
                                            self.complete?(persistableContentKey, nil, contentIdentifier)
                                        }
                                    } else {
                                        let drmError:FairPlayError = .ckcData(reason: "invalid persistableContentKeyx key")
                                        DataLog.e(drmError.getDescription(), tag: self.tag)
                                        DispatchQueue.main.async{
                                            self.complete?(nil, drmError, contentIdentifier)
                                        }
                                    }
                                    
                                    
                                } else {
                                    let drmError:FairPlayError = .ckcData(reason: "invalid ckc key")
                                    DataLog.e(drmError.getDescription(), tag: self.tag)
                                    DispatchQueue.main.async{
                                        self.complete?(nil, drmError, contentIdentifier)
                                    }
                                }
                            }
                            task.resume()
                        }
                }
            }
        }
        
        func contentKeySession(_ session: AVContentKeySession, didUpdatePersistableContentKey persistableContentKey: Data, forContentKeyIdentifier keyIdentifier: Any) {
            
            guard let identifier = keyIdentifier as? String else {return}
            guard let contentIdentifier = identifier.replacingOccurrences(of: "skd://", with: "") as String? else {return}
            DispatchQueue.main.async{
                self.prevPersistableContentKey[contentIdentifier] = persistableContentKey
                self.complete?(persistableContentKey, nil, contentIdentifier)
            }
            DataLog.d("didUpdatePersistableContentKey " + contentIdentifier, tag: self.tag)
            
        }
        
        func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: Error){
            DataLog.e("didFailWithError " + err.localizedDescription, tag: self.tag)
        }
        
        func contentKeySession(_ session: AVContentKeySession, contentKeyRequestDidSucceed keyRequest: AVContentKeyRequest) {
            DataLog.d("contentKeyRequestDidSucceed", tag: self.tag)
        }
        
        func contentKeySessionContentProtectionSessionIdentifierDidChange(_ session: AVContentKeySession) {
            DataLog.d("contentKeySessionContentProtectionSessionIdentifierDidChange", tag: self.tag)
        }
        
        func contentKeySessionDidGenerateExpiredSessionReport(_ session: AVContentKeySession){
            DataLog.d("contentKeySessionDidGenerateExpiredSessionReport", tag: self.tag)
        }
        
    }
}
