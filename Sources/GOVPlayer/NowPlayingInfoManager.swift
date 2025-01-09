//
//  NowPlayingInfoManager.swift
//  BtvPlus
//
//  Created by JeongCheol Kim on 2021/02/01.
//  Copyright © 2021 skb. All rights reserved.
//

import Foundation
import AVKit
import MediaPlayer
import GOLibrary

open class NowPlayingInfoManager: GOVPlayerProtocol {
   
    private(set) var contentId: String = ""
    private(set) var title: String = ""
    private var duration: Double = 0
    private var isNowPlay:Bool = false
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
   
    open func updateMetaData(contentId:String, title:String,  endCredit:Double? = nil) {
        if self.contentId == contentId {return}
        self.contentId = contentId
        self.title = title
        DataLog.d("[NowPlayingInfo contentId] " + contentId, tag:self.tag)
        DataLog.d("[NowPlayingInfo title] " + title, tag:self.tag)
    }
    
    public func updateArtwork(imageData:UIImage) {
        if self.contentId == contentId {return}
        guard var nowPlayingInfo = self.nowPlayingInfoCenter.nowPlayingInfo else {
            return
        }
        ComponentLog.d("updateArtwork", tag:"MPNowPlayingInfo")
        let artwork = MPMediaItemArtwork(boundsSize:.init(width: 240, height: 240)) { sz in
            return imageData
        }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    open func updatePlayNow(duration: Double, initTime: Double, isPlay: Bool = false) {
        if self.contentId.isEmpty { return }
        self.isNowPlay = true
        self.duration = duration
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = self.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = initTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlay ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] = contentId
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = 0
        self.nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
       
        DataLog.d("[NowPlayingInfo updatePlayNow] " + duration.description
                        + " / " + initTime.description
                        + " / " + isPlay.description, tag:self.tag)
        
    }
    open func updatePlay(time: Double, isPlay: Bool = false, rate:Float) {
        if self.contentId.isEmpty { return }
        let nowPlayingInfo = self.nowPlayingInfoCenter.nowPlayingInfo
        if var nowPlaying = nowPlayingInfo {
            /*
            let current = nowPlaying[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String
            if current != self.contentId {
                DataLog.t("[NowPlayingInfo current contentIdentifier] " + (current ?? "empty"), tag:self.tag)
                DataLog.t("[NowPlayingInfo contentIdentifier ] " + contentId, tag:self.tag)
                if !isPlay {
                    self.updatePlayNow(duration: self.duration, initTime:time, isPlay:true)
                } else {
                    if isPlay {
                        DataLog.t("[NowPlayingInfo auto pause] " + contentId, tag:self.tag)
                        //self.playerModel?.streamEvent = .takeAwayNowPlayingInfo
                        self.playerModel?.request = .pause()
                    }
                }
                return
            }
            */
            let d = self.duration
            let isNowPlay = self.isNowPlay
            nowPlaying[MPNowPlayingInfoPropertyCurrentPlaybackDate] = Date()
            if d > 0 {
                if d < time {
                    return
                } else {
                    if !isNowPlay {
                        self.updatePlayNow(duration: self.duration, initTime:time, isPlay:true)
                        return
                    }
                }
                let ratio = time / d
                nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
                nowPlaying[MPNowPlayingInfoPropertyPlaybackProgress] = ratio
            }
            nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = isPlay ? rate : 0.0
            self.nowPlayingInfoCenter.nowPlayingInfo = nowPlaying
        } else {
            DataLog.d("[NowPlayingInfo updatePlay nowPlayingInfo empty]" , tag:self.tag)
            self.updatePlayNow(duration: self.duration, initTime:time, isPlay:true)
        }
    }
    

    open func updateStop() {
        if self.contentId.isEmpty { return }
        if !self.isNowPlay {return}
        self.nowPlayingInfoCenter.nowPlayingInfo = nil
        self.isNowPlay = false
        self.contentId = ""
        DataLog.d("[NowPlayingInfo updateStop]", tag:self.tag)
    }
}
