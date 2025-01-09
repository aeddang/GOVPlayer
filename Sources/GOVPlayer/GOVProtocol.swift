// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftUI
import Foundation
import AVFoundation
import GOLibrary



protocol GOVPlayerProtocol {}
extension GOVPlayerProtocol {
    var tag:String {
        get{ "\(String(describing: Self.self))" }
    }
}

protocol GOVPlayBack:GOVPlayerProtocol {
    var viewModel:GOVPlayer.ViewModel {get set}
    func excute(_ request:GOVPlayer.Request, controller:GOVAVPlayerController?)
    func onStandby()
    func onTimeChange(_ t:Double)
    func onDurationChange(_ t:Double)
    func onLoad()
    func onLoaded()
    func onSeek(time:Double, isAfterplay:Bool?)
    func onSeeked()
    func onResumed()
    func onPaused()
    func onReadyToPlay()
    func onToMinimizeStalls()
    func onBuffering(rate:Double)
    func onBufferCompleted()
    func onStoped()
    func onCompleted()
    func onPipStateChanged(_ State:GOVPlayer.PipState)
    func onPipStop(isStop:Bool)
    func onError(_ error:GOVPlayer.PlayerError)
    func onError(_ error:GOVPlayer.StreamError)
    func onVolumeChange(_ v:Float)
    func onMute(_ isMute:Bool)
    func onScreenRatioChange(_ ratio:CGFloat)
    func onRateChange(_ rate:Float)
    func onScreenGravityChange(_ gravity:AVLayerVideoGravity)
    func setAssetInfo(_ info:GOVPlayer.AssetPlayerInfo)
    func setSubtltle(_ langs: [GOVPlayer.LangType])
    func onBitrateChanged(_ bitrate: Double)
}
