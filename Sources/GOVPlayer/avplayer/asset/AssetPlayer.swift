import Foundation
import AVFoundation
import GOLibrary

extension GOVPlayer{
    class AssetPlayer: AVPlayer , GOVPlayerProtocol, Identifiable{
        private let keyProvider = AVContentKeyProvider()
        let id = UUID().description
        private var loaderQueue = DispatchQueue(label: "GOVAssetPlayer")
        private var drm:FairPlayDrm? = nil
        private var m3u8URL: URL? = nil
        private var delegate: AssetResourceLoader? = nil
        
        
        func play(m3u8URL: URL) {
            self.clearAsset()
            self.drm = nil
            self.m3u8URL = m3u8URL
            self.delegate?.redirectChecker?.cancel()
            self.delegate = nil
            let asset = AVURLAsset(url: m3u8URL)
            let item = AVPlayerItem(asset: asset)
            self.replaceCurrentItem(with: item )
        }
        
        func play(m3u8URL: URL, playerDelegate:GOVAssetPlayerDelegate? ,
                  assetInfo:AssetPlayerInfo? = nil,
                  drm:FairPlayDrm? = nil) {
            self.clearAsset()
            self.drm = drm
            self.m3u8URL = m3u8URL
            self.delegate = AssetResourceLoader(
                m3u8URL:m3u8URL,
                playerDelegate: playerDelegate,
                keyProvider:self.keyProvider,
                assetInfo:assetInfo, drm: drm)
            
            
            self.retryCount = 0
            if let drm = drm {
                if drm.certificate != nil {
                    self.playAsset()
                } else {
                    self.getCertificateData(drm: drm, delegate: playerDelegate)
                }
                
            } else {
                self.playAsset()
            }
        }
        func stop() {
            self.clearAsset()
            self.delegate?.redirectChecker?.cancel()
            self.delegate = nil
            
        }
        
        private var retryCount:Int = 0
        private func playAsset() {
            guard let customURL = m3u8URL else {return}
            
            let asset = AVURLAsset(url: customURL)
            asset.resourceLoader.setDelegate(self.delegate, queue: self.loaderQueue)
            let playerItem = AVPlayerItem(asset: asset)
            
            
            if let drmData = self.drm {
                if drmData.useOfflineKey {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        drmData.persistKeys.forEach{
                            self.keyProvider.addContentKey(contentId: $0.0, key: $0.1, date: $0.2)
                        }
                        self.keyProvider.bind(asset: asset, drm: drmData)
                    }
                    
                }
            }
            self.replaceCurrentItem(with: playerItem)
        }
        
        private func clearAsset(){
            //self.replaceCurrentItem(with: nil)
            self.currentItem?.asset.cancelLoading()
            self.currentItem?.cancelPendingSeeks()
        }
        
        func replaceURLWithScheme(_ scheme: String, url: URL) -> URL? {
            let urlString = scheme + url.absoluteString
            return URL(string: urlString)
        }
        
        func getCertificateData(drm:FairPlayDrm, delegate: GOVAssetPlayerDelegate? = nil)  {
            DataLog.d("getCertificateData", tag: self.tag)
            if drm.useOfflineKey {
                self.playAsset()
                return
            }
            guard let url = URL(string:drm.certificateURL) else {
                let drmError:FairPlayError = .certificate(reason: "certificateData url error")
                DataLog.e(drmError.getDescription(), tag: self.tag)
                delegate?.onAssetLoadError(.drm(drmError))
                return
            }
            var certificateRequest = URLRequest(url: url)
            certificateRequest.httpMethod = "POST"
            
            let api: PlayerApi = .init(network: PlayerNetwork())
            api.getLicenseData(
                ckcUR: drm.certificateURL, params: .init(),
                completion: {data in
                    guard let data = data else
                    {
                        let reason =  "no certificateData"
                        let drmError:FairPlayError = .certificate(reason: reason)
                        DataLog.e(drmError.getDescription(), tag: self.tag)
                        delegate?.onAssetLoadError(.drm(drmError))
                        return
                    }
                    drm.certificate =  data
                    self.playAsset()
                },
                error: { error in
                    let reason = error.localizedDescription
                    let drmError:FairPlayError = .certificate(reason: reason)
                    DataLog.e(drmError.getDescription(), tag: self.tag)
                    delegate?.onAssetLoadError(.drm(drmError))
                }
            )
            
        }
        
    }
}
