//
//  Drm.swift
//  BtvPlusNew
//
//  Created by JeongCheol Kim on 2021/07/19.
//

import Foundation
import SwiftUI

extension GOVPlayer{
    public enum AssetLoadError: Error {
        case url(reason:String), parse(reason:String), cancel
        func getDescription() -> String {
            switch self {
            case .parse(let reason):
                return "parse error " + reason
            case .url(let reason):
                return "url error " + reason
            case .cancel:
                return "user cancel"
            }
        }
        
        func getDomain() -> String {
            return "asset"
        }
        
        func getCode() -> Int {
            return -2
        }
    }
    
    public enum AssetLoadEvent {
        case keyReady(String?, Data?)
    }
    
    
    public class AssetPlayerInfo {
        private(set) var resolutions:[String] = []
        private(set) var captions:[String] = []
        private(set) var audios:[String] = []
        
        var selectedResolution:String? = nil
        var selectedCaption:String? = nil
        var selectedAudio:String? = nil
        
        func reset(){
            resolutions = []
            captions = []
            audios = []
        }
        func copy() -> AssetPlayerInfo{
            let new = AssetPlayerInfo()
            new.selectedResolution = self.selectedResolution
            new.selectedCaption = self.selectedCaption
            new.selectedAudio = self.selectedAudio
            return new
        }
        func addResolution(_ value:String){
            if self.resolutions.first(where: {$0 == value}) == nil {
                self.resolutions.append(value)
            }
        }
        func addCaption(_ value:String){
            if self.captions.first(where: {$0 == value}) == nil {
                self.captions.append(value)
            }
        }
        func addAudio(_ value:String){
            if self.audios.first(where: {$0 == value}) == nil {
                self.audios.append(value)
            }
        }
    }
}

public protocol GOVAssetPlayerDelegate{
    func onFindAllInfo(_ info: GOVPlayer.AssetPlayerInfo)
    func onDownLoadList(_ list: [String])
    func onAssetEvent(_ evt :GOVPlayer.AssetLoadEvent)
    func onAssetLoadError(_ error: GOVPlayer.PlayerError)
}
extension GOVAssetPlayerDelegate {
    func onFindAllInfo(_ info: GOVPlayer.AssetPlayerInfo){}
    func onDownLoadList(_ list: [String]){}
    func onAssetEvent(_ evt : GOVPlayer.AssetLoadEvent){}
    func onAssetLoadError(_ error: GOVPlayer.PlayerError){}
}
