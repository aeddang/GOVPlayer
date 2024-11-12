//
//  GOVPlayback.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//
import SwiftUI
import Foundation
import AVFoundation
import Combine

extension GOVPlayer {
    @MainActor public static var seekMoveDefaultValue:Double = 15
    open class ViewModel: ObservableObject {
        private var anyCancellable = Set<AnyCancellable>()
        public private(set) var path:String = ""
        /*사용자지정 속성*/
        private(set) var useAvPlayerController:Bool = false
        private(set) var useAvPlayerControllerUI:Bool = false
        
        /*event*/
        @Published public fileprivate(set) var request:Request? = nil{
            didSet{
                if request != nil { self.request = nil }
            }
        }
        
        @Published public fileprivate(set) var streamEvent:StreamEvent? = nil{
            didSet{
                if streamEvent != nil { self.streamEvent = nil }
            }
        }
       
        
        @Published public fileprivate(set) var error:PlayerError? = nil
        @Published public fileprivate(set) var playerState:State? = nil
        @Published public fileprivate(set) var streamState:StreamState? = nil
        @Published public fileprivate(set) var playerPipState:PipState = .off
        @Published public fileprivate(set) var playMode:Mode? = nil
        
        @Published public fileprivate(set) var volume:Float = -1
        @Published public fileprivate(set) var bitrate:Double? = nil
        @Published public fileprivate(set) var rate:Float = 1.0
        @Published public fileprivate(set) var assetInfo:AssetPlayerInfo? = nil
        @Published public fileprivate(set) var subtitles:[LangType]? = nil
        @Published public fileprivate(set) var caption:Caption = .init()
        
        @Published public fileprivate(set) var screenRatio:CGFloat = 1.0
        @Published public fileprivate(set) var screenGravity:AVLayerVideoGravity = .resizeAspect
        @Published public private(set) var playEvents:[Double:String] = [:]
        @Published public private(set) var nextEventTime:Double? = nil
        
        @Published public fileprivate(set) var isMute:Bool = false
        private(set) public var useLoof:Bool = false
        private(set) public var usePip:Bool = true // pip사용여부
        private(set) public var useSeeking:Bool = true // 비디오 서치 사용여부
        @Published public fileprivate(set) var allowSeeking:Bool? = nil
        @Published public private(set) var allowPip:Bool? = nil
        
        private(set) var drm:FairPlayDrm? = nil
        private(set) var prevCertificate:Data? = nil
        
        public fileprivate(set) var initTime:Double? = nil
        public fileprivate(set) var isLoaded:Bool = false
        public fileprivate(set) var timeProgress:Double = 0.0
        public fileprivate(set) var originTime:Double = 0.0
        public fileprivate(set) var originDuration:Double = 0.0
        public fileprivate(set) var streamStartTime:Double? = nil
        @Published public fileprivate(set) var time:Double = 0.0
        public fileprivate(set) var remainingTime:Double = 0.0
        @Published public fileprivate(set) var duration:Double? = nil
        
       
        // only file
        fileprivate var toMinimizeStallsCount:Int = 0
       
        public init(){}
        public convenience init(path: String) {
            self.init()
            self.path = path
        }
        
        
        @discardableResult
        public func reset(isAll:Bool)->ViewModel{
            if let cert = self.drm?.certificate {
                self.prevCertificate = cert
            }
            isLoaded = false
            path = ""
            drm = nil
            subtitles = nil
            playMode = nil
            duration = nil
            time = 0
            remainingTime = 0
            duration = nil
            originTime = 0
            originDuration = 0
            timeProgress = 0
            streamStartTime = nil
            initTime = nil
            allowSeeking = nil
            error = nil
            streamState = nil
            playerState = nil
            bitrate = nil
            assetInfo = nil
            subtitles = nil
            volume = AVAudioSession.sharedInstance().outputVolume
            if isAll {
                useSeeking = true
                usePip = true
                screenRatio = 1.0
                rate = 1.0
                isMute = false
                screenGravity = .resizeAspect
                nextEventTime = nil
                caption = .init()
            }
            return self
        }
       
        @discardableResult
        public func setup (
            mode:Mode? = nil,
            useSeeking:Bool? = nil,
            usePip:Bool? = nil,
            isMute:Bool? = nil,
            useLoof:Bool? = nil,
            rate:Float? = nil,
            screenRatio:CGFloat? = nil,
            screenGravity:AVLayerVideoGravity? = nil)->ViewModel{
            
            if let v = mode { self.playMode = v }
            if let v = useSeeking { self.useSeeking = v }
            if let v = usePip { self.usePip = v }
            if let v = isMute { self.isMute = v }
            if let v = useLoof { self.useLoof = v }
            if let v = rate { self.rate = v }
            if let v = screenRatio { self.screenRatio = v }
            if let v = screenGravity { self.screenGravity = v }
            return self
        }
        
        func onSetup(allowPip:Bool? = nil){
            if let v = allowPip { self.allowPip = v }
        }
        
        func setupExcuter (_ completion:@escaping (Request) -> Void) {
            self.requestHandler = completion
        }
        
        private var requestHandler:((Request) -> Void)? = nil
        @discardableResult
        public func excute(_ request:Request)->ViewModel {
            switch request {
            case .load(let path, _ , _):
                self.path = path
            default: break
            }
            self.request = request
            self.requestHandler?(request)
            return self
        }
        
       
    }

}

extension GOVPlayBack {
    func onStandby(){
        self.viewModel.streamState = .stop
    }
    
    func onTimeChange(_ t:Double){
        guard !(t.isNaN || t.isInfinite) else { return }
        guard let mode = self.viewModel.playMode else {return}
        self.viewModel.originTime = t
        if mode.isLive {
            self.onLivePlay(t)
        } else {
            self.onVodPlay(t)
        }
    }
    
    private func onVodPlay(_ t:Double){
        //guard let viewModel = self.viewModel else {return}
        guard let mode = viewModel.playMode else { return }
        guard let d = viewModel.duration else { return }
        if d <= 0 {return}
        if t < 0 {return}
        
        var start:Double = 0
        var end:Double = d
        var current:Double = t
        switch mode{
        case .section(let s, let e) :
            start = s ?? 0
            end = e ?? d
            current = max(0,t - start)
        default : break
        }
        if let evt = viewModel.playEvents[current] {
            viewModel.streamEvent = .playEvent(evt)
        }
        if let nt = viewModel.nextEventTime {
            let remainTime = end - nt
            if remainTime == current {
                viewModel.streamEvent = .next
            }
        }
        viewModel.remainingTime = end - current
        viewModel.timeProgress = current/end
        viewModel.time = current
        if current >= end {
            self.viewModel.excute(.pause)
            self.onCompleted()
        }
    }
    
    private func onLivePlay(_ t:Double){
        guard let mode = viewModel.playMode else { return }
        guard let streamStartTime = viewModel.streamStartTime else {return}
        var start:Double? = nil
        var end:Double? = nil
        var current:Double = t
        
        switch mode{
        case .live(let s, let e) :
            start = s
            end = e
        default : return
        }
        guard let end = end, let start = start else {return}
        current = t + start - streamStartTime
        
        if let evt = viewModel.playEvents[current] {
            viewModel.streamEvent = .playEvent(evt)
        }
        
        if let nt = viewModel.nextEventTime {
            let remainTime = end - nt
            if remainTime == current {
                viewModel.streamEvent = .next
            }
        }
        viewModel.remainingTime = end - current
        viewModel.timeProgress = current/end
        viewModel.time = current
        if current >= end {
            DataLog.d("player completed timeRangeCompleted", tag:self.tag)
            viewModel.streamEvent = .timeRangeCompleted
            return
        }
    }
    
   
    
    func onDurationChange(_ t:Double){
        if viewModel.playMode == nil {
            let mode:GOVPlayer.Mode =  (t > 0) ? .vod : .live(start: nil, end: nil)
            self.viewModel.playMode = mode
        }
        guard let mode = viewModel.playMode else {return}
        viewModel.originDuration = t
        if t <= 0 { return }
        let allowSeeking = viewModel.useSeeking ? true : false
        viewModel.allowSeeking = allowSeeking
        switch mode{
        case .section(let s, let e) :
            viewModel.duration = min(t, e ?? t) - (s ?? 0)
        default :
            viewModel.duration = t
        }
    }
    
    func onPersistKeyReady(contentId:String?, ckcData:Data?){
        viewModel.streamEvent = .persistKeyReady(contentId, ckcData)
    }
    
    func onLoad(){
        DataLog.d("onLoad", tag: self.tag)
        self.checkSeeked()
        viewModel.playerState = .load
        
    }
    func onLoaded(){
        DataLog.d("onLoaded", tag: self.tag)
        viewModel.isLoaded = true
        viewModel.streamEvent = .loaded(viewModel.path)
        viewModel.streamStartTime = Date().timeIntervalSince1970
    }
    func onSeek(time:Double, isAfterplay:Bool?){
        guard let State = viewModel.playerState else { return }
        if !State.isStreaming {
            DataLog.d("onSeek disable State", tag: self.tag)
            return
        }
        let t = time
        let isPlay = State.isPlaying
        DataLog.d("onSeek " + t.description, tag: self.tag)
        
        viewModel.playerState = .seek(time, isPrevPlay: isPlay, isAfterPlay: isAfterplay)
        if !State.isPlaying {
            self.onSeeked()
        } else if abs(t-viewModel.time) <= 1 {
            self.onSeeked()
        }
    }
    func checkSeeked(){
        switch viewModel.playerState {
        case .seek: onSeeked()
        default: break
        }
    }
    
    func onSeeked(){
        DataLog.d("onSeeked", tag: self.tag)
        viewModel.streamEvent = .seeked
        switch viewModel.playerState {
        case .seek(_ , let isPrevPlay, let isAfterPlay):
            viewModel.playerState = isPrevPlay ? .resume : .pause
            if let afterPlay = isAfterPlay {
                viewModel.request = afterPlay ? .resume : .pause
            }
        default : break
        }
    }
    
    func onResumed(){
        self.checkSeeked()
        DataLog.d("onResumed", tag: self.tag)
        viewModel.playerState = .resume
        viewModel.streamEvent = .resumed
        onBufferCompleted()
    }
    func onPaused(){
        self.checkSeeked()
        if viewModel.playerState?.isPlay == false {
            return
        }
       
        viewModel.playerState = .pause
        viewModel.streamEvent = .paused
        if viewModel.toMinimizeStallsCount > 1 {
            onError( .stream(.playback("toMinimizeStalls")) )
            onBufferCompleted()
        } else {
            onBufferCompleted()
        }
    }
    func onReadyToPlay(){
        DataLog.d("onReadyToPlay", tag: self.tag)
        onBufferCompleted()
        switch viewModel.playerState {
        case .load: onLoaded()
        case .seek: onSeeked()
        default: break
        }
        if !viewModel.isLoaded {onLoaded()}
    }
    
    func onToMinimizeStalls(){
        viewModel.toMinimizeStallsCount += 1
        onBuffering(rate:0)
    }
    
    func onBuffering(rate:Double = 0){
        viewModel.streamState = .buffering(rate)
        viewModel.streamEvent = .buffer
    }
    
    func onBufferCompleted(){
        self.checkSeeked()
        viewModel.toMinimizeStallsCount = 0
        if viewModel.streamState == .stop {return}
        viewModel.streamState = .playing
    }
    
    func onStoped(){
        if viewModel.playerState?.isStreaming == false {
            DataLog.d("already stoped", tag: self.tag)
            return
        }
        DataLog.d("onStoped", tag: self.tag)
        viewModel.playerState = .stop
        viewModel.streamState = .stop
        viewModel.streamEvent = .stoped
    }
    
    func onCompleted(){
        if viewModel.playerState?.isPlay != true {return}
        DataLog.d("onCompleted", tag: self.tag)
        viewModel.playerState = .complete
        viewModel.streamEvent = .completed
    }
    func onPipStateChanged(_ State:GOVPlayer.PipState){
        viewModel.playerPipState = State
    }
    func onPipStop(isStop:Bool){
        viewModel.streamEvent = .pipClosed(isStop)
    }
    func onError(_ error:GOVPlayer.StreamError){
        DataLog.e("onError" + error.getDescription(), tag: self.tag)
        viewModel.error = .stream(error)
        viewModel.streamState = .stop
        viewModel.playerState = .error
        viewModel.streamEvent = .stoped
    }
    func onError(_ error:GOVPlayer.PlayerError){
        DataLog.e("onError" + error.getDescription(), tag: self.tag)
        viewModel.error = error
        viewModel.streamState = .stop
        viewModel.playerState = .error
        viewModel.streamEvent = .stoped
    }
    
    func onVolumeChange(_ v:Float){
        viewModel.volume = v
    }
    func onMute(_ isMute:Bool){
        viewModel.isMute = isMute
    }
    func onScreenRatioChange(_ ratio:CGFloat){
        viewModel.screenRatio = ratio
    }
    func onRateChange(_ rate:Float){
        viewModel.rate = rate
    }
    func onScreenGravityChange(_ gravity:AVLayerVideoGravity){
        viewModel.screenGravity = gravity
        viewModel.screenRatio = 1
    }
    
    func onCaptionChange(_ lang:String? = nil, size:CGFloat? = nil , color:Color? = nil){
        if let v = size { viewModel.caption.size = v}
        if let v = color { viewModel.caption.color = v}
        if let lang = lang {
            viewModel.caption.lang = GOVPlayer.LangType.getType(lang)
        } else {
            viewModel.caption.lang = nil
        }
    }
    
    func setAssetInfo(_ info:GOVPlayer.AssetPlayerInfo) {
        viewModel.assetInfo = info
    }
    
    func setSubtltle(_ langs: [GOVPlayer.LangType]) {
        viewModel.subtitles = langs
        
    }
    func onBitrateChanged(_ bitrate: Double) {
        viewModel.bitrate = bitrate
    }
    
}
