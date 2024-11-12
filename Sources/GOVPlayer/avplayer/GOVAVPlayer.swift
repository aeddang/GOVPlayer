//
//  PlayerScreenView.swift
//  BtvPlusNew
//
//  Created by JeongCheol Kim on 2021/02/04.
//

import Foundation
import SwiftUI
import Combine
import AVKit
import MediaPlayer


protocol GOVAVPlayerDelegate{
    func onPlayerPersistKeyReady(contentId:String?,ckcData:Data?)
    func onPlayerAssetInfo(_ info:GOVPlayer.AssetPlayerInfo)
    func onPlayerError(streamError:GOVPlayer.StreamError)
    func onPlayerError(playerError:GOVPlayer.PlayerError)
    func onPlayerCompleted()
    func onPlayerBecomeActive()
    func onPlayerBitrateChanged(_ bitrate:Double)
    func onPlayerSubtltle(_ langs:[GOVPlayer.LangType])
    func onPipStateChanged(_ isStart:Bool)
    func onPipClosed(isStop:Bool)
}


protocol GOVAVPlayerRunningDelegate{
    func onPlayerReady()
    func onPlayerDestory()
}
extension GOVPlayer {
    class GOVAVPlayer: UIView, @preconcurrency AVPictureInPictureControllerDelegate, @preconcurrency GOVAssetPlayerDelegate , GOVPlayerProtocol, Identifiable {
        let appTag = "myTvPlayer" + UUID.init().uuidString
        let id:String = UUID.init().uuidString
        private var viewModel:ViewModel? = nil
        private var delegate:GOVAVPlayerDelegate? = nil
        private var runningDelegate:GOVAVPlayerRunningDelegate? = nil
        
        
        private var playerController : AVPlayerViewController? = nil{didSet{self.bindPlayer()}}
        private var playerLayer:AVPlayerLayer? = nil {didSet{self.bindPlayer()}}
        private(set) var player:GOVPlayer.AssetPlayer? = nil {didSet{self.bindPlayer()}}
        private func bindPlayer(){
            guard let player = self.player else {return}
            if let controller = self.playerController {
                controller.player = player
                controller.updatesNowPlayingInfoCenter = true
                controller.videoGravity = self.currentVideoGravity
                controller.allowsPictureInPicturePlayback = self.usePip
            }else if let playerLayer = self.playerLayer {
                playerLayer.player = player
                playerLayer.contentsScale = self.currentRatio
                playerLayer.videoGravity = self.currentVideoGravity
                layer.addSublayer(playerLayer)
            }
        }
        
        private var drmData:FairPlayDrm? = nil
        private(set) var currentVolume:Float = 1.0
        private var isAutoPlay:Bool = false
        private var initTime:Double = 0
        
        private var pipController:AVPictureInPictureController? = nil
        private var usePip:Bool = false
        private var currentUsePip:Bool = false
        private var isPip:Bool = false
        private var isPipClose:Bool = true
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            DataLog.d("init " + id, tag: self.tag)
        }
        
        required init?(coder: NSCoder) {fatalError("init(coder:) has not been implemented")}
        
        deinit {
            DataLog.d("deinit " + id, tag: self.tag)
        }
        
        func setup(
            viewModel:ViewModel? = nil,
            delegate:GOVAVPlayerDelegate? = nil,
            runningDelegate:GOVAVPlayerRunningDelegate? = nil,
            playerController : AVPlayerViewController? = nil){
                
                self.viewModel = viewModel
                self.delegate = delegate
                self.runningDelegate = runningDelegate
                self.playerController = playerController
            
        }
        
        func stop() {
            guard let player = self.player else {return}
            player.pause()
            player.stop()
            player.currentItem?.cancelPendingSeeks()
            player.currentItem?.asset.cancelLoading()
            player.replaceCurrentItem(with: nil)
            DataLog.d("on Stop " + id, tag: self.tag)
        }
        func destory(){
            DataLog.d("destory " + id , tag: self.tag)
            self.destoryPlayer()
            self.destoryScreenview()
        }
        func destoryScreenview(){
            self.playerLayer = nil
            self.delegate = nil
            self.runningDelegate = nil
            self.playerController = nil
            self.player = nil
            DataLog.d("destoryScreenview " + id, tag: self.tag)
        }
        private func destoryPlayer(){
            if self.isPip {
                self.isPip = false
                self.delegate?.onPipStateChanged(false)
            }
            self.stop()
            playerLayer?.removeFromSuperlayer()
            playerLayer?.player = nil
            if let avPlayerViewController = playerController {
                avPlayerViewController.player = nil
                avPlayerViewController.delegate = nil
            }
            NotificationCenter.default.removeObserver(self)
            self.runningDelegate?.onPlayerDestory()
            self.player?.stop()
            self.pipController = nil
            self.playerLayer = nil
            self.player = nil
            DataLog.d("destoryPlayer " + id, tag: self.tag)
        }
        
        private func createdPlayer(){
            self.runningDelegate?.onPlayerReady()
            let center = NotificationCenter.default
            center.addObserver( self, selector:#selector(failedToPlayToEndTime), name: .AVPlayerItemFailedToPlayToEndTime, object:self.appTag)
            center.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: self.appTag)
            center.addObserver(self, selector: #selector(playerDidBecomeActive), name: UIApplication.didBecomeActiveNotification , object:self.appTag)
            center.addObserver(self,
                               selector: #selector(playerAVAudioSessionInterruption),
                               name: AVAudioSession.interruptionNotification,
                               object: AVAudioSession.sharedInstance())
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width * currentRatio
            let h = bounds.height * currentRatio
            let x = (bounds.width - w) / 2
            let y = (bounds.height - h) / 2
            playerLayer?.frame = CGRect(x: x, y: y, width: w, height: h)
        }
        
        private func createPlayer(_ url:URL, buffer:Double = 2.0, header:[String:String]? = nil, assetInfo:AssetPlayerInfo? = nil) -> AVPlayer?{
            
            var player:AVPlayer? = nil
            if self.drmData != nil {
                player = startPlayer(url, assetInfo:assetInfo)
            }else if let header = header {
                player = startPlayer(url, header: header)
            }else{
                player = startPlayer(url, assetInfo:assetInfo)
            }
            return player
        }
        
        private func startPlayer(_ url:URL, header:[String:String]) -> AVPlayer?{
           
            let player = self.player ?? AssetPlayer()
            var assetHeader = [String: Any]()
            assetHeader["AVURLAssetHTTPHeaderFieldsKey"] = header
            let key = "playable"
            let asset = AVURLAsset(url: url, options: assetHeader)
            
            asset.loadValuesAsynchronously(forKeys: [key]){
                DispatchQueue.global(qos: .background).async {
                    let status = asset.statusOfValue(forKey: key, error: nil)
                    switch (status)
                    {
                    case AVKeyValueStatus.failed, AVKeyValueStatus.cancelled, AVKeyValueStatus.unknown:
                        DataLog.d("certification fail " + url.absoluteString , tag: self.tag)
                        DispatchQueue.main.async {
                            self.onError( .certification(status.rawValue.description))
                        }
                    default:
                        //ComponentLog.d("certification success " + url.absoluteString , tag: self.tag)
                        DispatchQueue.main.async {
                            let item = AVPlayerItem(asset: asset)
                            player.replaceCurrentItem(with: item )
                            self.startPlayer(player:player)
                        }
                        break;
                    }
                }
            }
            return player
        }
        
        private func startPlayer(_ url:URL, assetInfo:AssetPlayerInfo? = nil)  -> AVPlayer?{
            DataLog.d("DrmData " +  (drmData?.contentId ?? " none drm") , tag: self.tag)
            let player = self.player ?? AssetPlayer()
            player.pause()
            if self.drmData == nil {
                player.play(m3u8URL: url)
            } else {
                player.play(m3u8URL: url, playerDelegate: self, assetInfo:assetInfo, drm: self.drmData)
            }
            self.startPlayer(player:player)
            return player
        }
        
        private func startPlayer(player:AssetPlayer){
            if self.player == nil {

                self.player = player
                player.allowsExternalPlayback = true
                player.usesExternalPlaybackWhileExternalScreenIsActive = true
                player.preventsDisplaySleepDuringVideoPlayback = true
                player.appliesMediaSelectionCriteriaAutomatically = false
                player.preventsDisplaySleepDuringVideoPlayback = true
                player.volume = self.currentVolume
                
                if let avPlayerViewController = self.playerController {
                    avPlayerViewController.player = player
                    avPlayerViewController.updatesNowPlayingInfoCenter = true
                    avPlayerViewController.allowsPictureInPicturePlayback = self.usePip
                }else {
                    if self.playerLayer == nil {
                        self.playerLayer = AVPlayerLayer()
                    }
                }
                DataLog.d("startPlayer currentVolume " + self.currentVolume.description , tag: self.tag)
                DataLog.d("startPlayer currentRate " + self.currentRate.description , tag: self.tag)
                DataLog.d("startPlayer videoGravity " + self.currentVideoGravity.rawValue , tag: self.tag)
                self.createdPlayer()
                self.setupPictureInPicture()
            }
            
        }
        
        func updatePictureInPicture(_ usePip:Bool) {
            self.usePip = usePip
            self.setupPictureInPicture()
        }
        private func setupPictureInPicture() {
            if !self.usePip {
                if self.isPip {
                    self.onPipStop()
                }
                self.currentUsePip = false
                pipController?.delegate = nil
                pipController = nil
                self.viewModel?.onSetup(allowPip: false)
                return
                
            }
            if AVPictureInPictureController.isPictureInPictureSupported() {
                self.viewModel?.onSetup(allowPip: true)
                guard let layer = self.playerLayer else {
                    self.playerController?.allowsPictureInPicturePlayback = self.usePip
                    return
                }
                
                if !self.currentUsePip && self.pipController == nil{
                    pipController = AVPictureInPictureController(playerLayer: layer)
                    if #available(iOS 14.2, *) {
                        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
                    } 
                    pipController?.delegate = self
                    self.currentUsePip = true
                }
                
            } else {
                self.viewModel?.onSetup(allowPip: false)
                self.currentUsePip = false
                pipController?.delegate = nil
                pipController = nil
            }
        }
        
        private func onError(_ e:StreamError){
            delegate?.onPlayerError(streamError: e)
            DataLog.e("onError " + e.getDescription(), tag: self.tag)
            destoryPlayer()
        }
       
        
        @objc func failedToPlayToEndTime(_ notification: Notification) {
            guard let userInfo = notification.userInfo else { return }
            let e = userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey]
            if let error = e as? NSError {
                let code = error.code
                if code != -1102 { // 재생구간 오류
                    onError(.playback(error.localizedDescription))
                }
            }else{
                onError(.unknown("failedToPlayToEndTime"))
            }
            
        }
        @objc func playerItemDidReachEnd(notification: NSNotification) {
            delegate?.onPlayerCompleted()
        }
        @objc func playerDidBecomeActive(notification: NSNotification) {
            delegate?.onPlayerBecomeActive()
        }
        @objc func playerAVAudioSessionInterruption(notification: NSNotification) {
            DataLog.t("[onAVAudioSessionInterruption] notification " + notification.debugDescription , tag:self.tag)
        }
                
        @discardableResult
        func load(_ path:String, isAutoPlay:Bool = false ,
                  initTime:Double = 0,
                  buffer:Double = 2.0,
                  header:[String:String]? = nil,
                  assetInfo:AssetPlayerInfo? = nil,
                  drmData:FairPlayDrm? = nil
        ) -> AVPlayer? {
            if self.currentUsePip != self.usePip {
                self.setupPictureInPicture()
            }
            var assetURL:URL? = nil
            if path.hasPrefix("http") {
                assetURL = URL(string: path)
            } else {
                assetURL = URL(fileURLWithPath: path)
            }
            guard let url = assetURL else { return nil }
            self.initTime = initTime
            self.isAutoPlay = isAutoPlay
            self.drmData = drmData
            do {
                try AVAudioSession.sharedInstance()
                    .setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                
            }
            catch {
                DataLog.e("Setting category to AVAudioSessionCategoryPlayback failed." , tag: self.tag)
            }
            let player = createPlayer(url, buffer:buffer, header:header, assetInfo: assetInfo)
            return player
        }
        
        
        func playInit(){
            DispatchQueue.main.async {
                if self.isAutoPlay { self.resume() }
                else { self.pause() }
            }
            self.checkCaption()
            
        }
        func playInit(duration:Double){
            DataLog.d("playInit " + duration.description + " initTime " + self.initTime.description, tag: self.tag)
            guard let currentPlayer = player else { return }
            
            if self.currentRate != 1 {
                DispatchQueue.main.async {
                    currentPlayer.rate = self.currentRate
                }
            }
            DispatchQueue.main.async {
                if self.isAutoPlay { self.resume() }
                else { self.pause() }
                if ceil(self.initTime) > 0 && duration > 0 {
                    let diff:Double = duration - self.initTime
                    let seekAble = self.viewModel?.allowSeeking ?? true
                    DataLog.d("continuousTime " + seekAble.description + " diff " + diff.description, tag: self.tag)
                    if seekAble && diff < 10  { // 10이하 남은곳으로 이동시 처음부터
                        DataLog.d("continuousTime cancel " + diff.description + " " + self.initTime.description , tag: self.tag)
                        return
                    }
                    DataLog.d("continuousTime " + self.initTime.description, tag: self.tag)
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.01) {
                        self.seek(self.initTime)
                    }
                }
            }
            self.checkCaption()
            
        }
        
        private func checkCaption(){
            guard let currentItem = self.player?.currentItem else { return }
            var langs:[LangType] = []
            let findLang = self.viewModel?.caption.lang
            var selectLang:LangType? = nil
            currentItem.asset.allMediaSelections.forEach{ item in
                //DataLog.d(item.debugDescription, tag: self.tag)
                if let find = LangType.allCases.first(where: { lang in
                    let info = item.debugDescription
                    let key = "language = " + lang.rawValue
                    let sbtKey = "sbtl"
                    return info.contains(key) && info.contains(sbtKey)
                }) {
                    langs.append(find)
                    if find == findLang {
                        selectLang = find
                    }
                }
            }
            if findLang != nil && selectLang == nil {
                selectLang = langs.first
            }
            
            DispatchQueue.main.async {
                self.delegate?.onPlayerSubtltle(langs)
                if let lang = selectLang {
                    
                    self.captionChange(
                        lang: lang.rawValue,
                        size: self.viewModel?.caption.size,
                        color: self.viewModel?.caption.color,
                        position: 90)
                }
            }
            
        }
        
        @discardableResult
        func resume() -> Bool {
            guard let currentPlayer = player else { return false }
            currentPlayer.play()
            currentPlayer.rate = currentRate
            return true
        }
        
        @discardableResult
        func pause() -> Bool {
            guard let currentPlayer = player else { return false }
            currentPlayer.pause()
            return true
        }
        
        @discardableResult
        func seek(_ t:Double) -> Bool {
            guard let currentPlayer = player else { return false }
            currentPlayer.currentItem?.cancelPendingSeeks()
            let rt = round(t)
            DataLog.d("onSeek request " + rt.description, tag: self.tag)
            let cmt = CMTime(
                value: CMTimeValue(rt*10),
                timescale: CMTimeScale(10))
            currentPlayer.seek(to: cmt)
            return true
        }
        
        @discardableResult
        func seekMove(_ t:Double) -> Bool {
            guard let currentPlayer = player else { return false }
            currentPlayer.currentItem?.cancelPendingSeeks()
            DataLog.d("onSeek move request " + t.description, tag: self.tag)
            let rt = round(t) + Double(currentPlayer.currentItem?.currentTime().seconds ?? 0)
            return self.seek(rt)
        }
        
        
        @discardableResult
        func mute(_ isMute:Bool) -> Bool {
            currentVolume = isMute ? 0.0 : 1.0
            guard let currentPlayer = player else { return false }
            currentPlayer.volume = currentVolume
            return true
        }
        
        func movePlayerVolume(_ v:Float){
            guard let currentPlayer = player else { return }
            withAnimation{
                currentPlayer.volume = v
            }
        }
        
        func setArtwork(_ imageData:UIImage){
            guard let item = self.player?.currentItem else {return}
            guard let data = imageData.jpegData(compressionQuality: 1) as? NSData else {return}
            let artwork = AVMutableMetadataItem()
            artwork.identifier = .commonIdentifierArtwork
            artwork.value = data
            artwork.dataType = kCMMetadataBaseDataType_JPEG as String
            artwork.extendedLanguageTag = "und"
            item.externalMetadata = [artwork]
        }
    
        @discardableResult
        func pip(isStart:Bool) -> Bool {
            guard let pip = self.pipController else { return false }
            DispatchQueue.main.async {
                isStart ? pip.startPictureInPicture() : pip.stopPictureInPicture()
            }
            return true
        }
        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            pictureInPictureController.requiresLinearPlayback = !(self.viewModel?.allowSeeking ?? true)
            self.isPip = true
            self.isPipClose = true
            self.delegate?.onPipStateChanged(true)
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.onPipStop()
        }
        
        private func onPipStop(){
            self.isPip = false
            self.delegate?.onPipStateChanged(false)
            self.delegate?.onPipClosed(isStop: self.isPipClose)
        }
        
        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
            DataLog.d("failedToStartPictureInPictureWithError " + error.localizedDescription ,tag: "pipController")
        }
        
        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            self.isPipClose = false
            
            DataLog.d("restoreUserInterfaceForPictureInPictureStopWithCompletionHandler" ,tag: "pipController")
        }
        
        
        func captionChange(lang:String?, size:CGFloat?, color:Color?, position:CGFloat){
            guard let currentPlayer = player else { return }
            guard let currentItem = currentPlayer.currentItem else { return }
            currentItem.asset.loadMediaSelectionGroup(for: .legible){group,_ in
                if let group = group {
                    let locale = Locale(identifier: lang ?? "")
                    let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
                    if lang == LangType.notUsed.rawValue {
                        currentItem.select(nil, in: group)
                    }else if lang?.isEmpty == false {
                        if let option = options.first {
                            currentItem.select(option, in: group)
                        }
                    }else {
                        currentItem.select(nil, in: group)
                    }
                    let size = (size ?? 100)
                    // let component = color.components()
                    guard let rule = AVTextStyleRule(textMarkupAttributes: [
                        kCMTextMarkupAttribute_RelativeFontSize as String : size,
                        kCMTextMarkupAttribute_OrthogonalLinePositionPercentageRelativeToWritingDirection as String: position
                    ]) else { return }
                    currentItem.textStyleRules = [rule]
                }
                
            }
            
        }
        
        // asset delegate
        func onFindAllInfo(_ info: AssetPlayerInfo) {
            self.delegate?.onPlayerAssetInfo(info)
        }
        
        func onAssetLoadError(_ error: PlayerError) {
            self.delegate?.onPlayerError(playerError: error)
        }
        
        func onAssetEvent(_ evt :AssetLoadEvent) {
            switch evt {
            case .keyReady(let contentId, let ckcData):
                self.delegate?.onPlayerPersistKeyReady(contentId:contentId, ckcData: ckcData)
                if self.isAutoPlay { self.resume() }
                else { self.pause() }
            }
        }
        
        var currentPlayTime:Double? {
            get{
                self.player?.currentItem?.currentTime().seconds
            }
        }
        
        
        var currentRatio:CGFloat = 1.0
        {
            didSet{
                //ComponentLog.d("onCurrentRatio " + currentRatio.description, tag: self.tag)
                if let layer = playerLayer {
                    layer.contentsScale = currentRatio
                    self.setNeedsLayout()
                }
            }
        }
        
        var currentVideoGravity:AVLayerVideoGravity = .resizeAspectFill
        {
            didSet{
                if let avPlayerViewController = playerController {
                    avPlayerViewController.videoGravity = currentVideoGravity
                } else {
                    playerLayer?.videoGravity = currentVideoGravity
                }
            }
        }
        
        var currentRate:Float = 1.0
        {
            didSet{
                player?.rate = currentRate
            }
        }
        
    }
    
}
