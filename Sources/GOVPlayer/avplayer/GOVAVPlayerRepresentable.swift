//
//  GOVAVPlayerUI.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 11/5/24.
//
import Foundation
import SwiftUI
import Combine
import AVKit
import MediaPlayer


extension GOVAVPlayerRepresentable: UIViewControllerRepresentable,
                                    GOVAVPlayerDelegate ,
                                    @preconcurrency GOVAVPlayerControllerDelegate{
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<GOVAVPlayerRepresentable>) -> UIViewController {
        
        let player = GOVPlayer.GOVAVPlayer(frame: .infinite)
        player.mute(viewModel.isMute)
        player.currentRate = viewModel.rate
        player.currentVideoGravity = viewModel.screenGravity
        player.currentRatio = viewModel.screenRatio
        
        
        if viewModel.useAvPlayerController{
            let playerController = CustomAVPlayerViewController(
                viewModel: viewModel, player: player, playerDelegate: self
            )
            playerController.delegate = context.coordinator
            playerController.showsPlaybackControls = viewModel.useAvPlayerControllerUI
            playerController.allowsPictureInPicturePlayback = viewModel.usePip
            if #available(iOS 14.2, *) {
                playerController.canStartPictureInPictureAutomaticallyFromInline = viewModel.usePip
            }
            player.setup(
                viewModel: viewModel,
                delegate: self,
                runningDelegate: playerController,
                playerController: playerController
            )
            DispatchQueue.main.async {
                self.onStandby()
            }
            self.viewModel.setupExcuter(){ request in
                self.excute(request, controller: playerController)
            }
            return playerController
            
        }else{
            let playerController = CustomPlayerViewController(
                viewModel: self.viewModel, player: player, playerDelegate: self
            )
            playerController.view = player
            player.setup(
                viewModel: self.viewModel,
                delegate: self,
                runningDelegate: playerController
            )
            DispatchQueue.main.async {
                self.onStandby()
            }
            self.viewModel.setupExcuter(){ request in
                self.excute(request, controller: playerController)
            }
            return playerController
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<GOVAVPlayerRepresentable>) {
    }
     
   
    func onPipStateChanged(_ isStart:Bool){
        self.onPipStateChanged(isStart ? .on : .off)
    }
    func onPipClosed(isStop:Bool){
        self.onPipStop(isStop: isStop)
    }
    
    @MainActor
    func excute(_ request: GOVPlayer.Request, controller:GOVAVPlayerController?) {
        guard let player = controller?.govPlayer else {return}
        switch request {
        case .load(let path, let autoPlay, let initTime):
            viewModel.reset(isAll: false)
            self.onLoad()
            player.load(path, isAutoPlay:autoPlay, initTime: initTime,
                        assetInfo: self.viewModel.assetInfo, drmData: viewModel.drm)
            
        
           
        case .togglePlay:
            if self.viewModel.playerState?.isPlaying == true {
                onPause()
            } else {
                onResume()
            }
        case .resume: onResume()
        case .pause: onPause()
        case .stop:
            viewModel.reset(isAll: false)
            self.removeRemoteAction()
            player.stop()
            self.onStoped()
            
        case .volume(let v):
            MPVolumeView.setVolume(v)
            self.onVolumeChange(v)
            if v > 0 && player.currentVolume == 0 {
                self.onMute(false)
                player.mute(false)
            } else if v == 0 {
                self.onMute(true)
                player.mute(true)
            }
        case .mute(let isMute):
            self.onMute(isMute)
            player.mute(isMute)
            
        case .screenRatio(let r):
            player.currentRatio = r
            self.onScreenRatioChange(r)
            
        case .rate(let r):
            player.currentRate = r
            self.onRateChange(r)
           
        case .screenGravity(let gravity):
            player.currentVideoGravity = gravity
            player.currentRatio = 1
            self.onScreenGravityChange(gravity)
        case .seek(let time, let andPlay) : onSeek(time:time, play: andPlay)
        case .seekProgress(let progress, let andPlay) :
            let t = (viewModel.duration ?? 0) * Double(progress)
            onSeek(time:t, play: andPlay)
        case .seekMove(let moveTime , let andPlay) :
            onSeek(time:viewModel.time + moveTime , play: andPlay)
        case .captionChange(let lang, let size, let color, let position) :
            onCaptionChange(lang, size: size, color: color)
            player.captionChange(lang: lang, size: size, color: color, position:position ?? 85)

        case .pip(let isStart) :
            player.pip(isStart: isStart)
        case .usePip(let usePip) :
            player.updatePictureInPicture(usePip)
        default : break
        }
        
        func onResume(){
            if viewModel.playerState == .complete {
                onSeek(time: 0, play:true)
                return
            }
            if !player.resume() {
                self.onPlayerError(playerError: .illegalState(.resume))
                return
            }
        }
        func onPause(){
            if !player.pause() {
                self.onPlayerError(playerError: .illegalState(.pause))
            }
        }
        
        func onSeek(time:Double, play:Bool?){
            
            guard let mode = viewModel.playMode else { return }
            guard let d = viewModel.duration else { return }
            var start:Double = 0
            var end:Double = d
            switch mode{
            case .section(let s, let e) :
                start = s ?? 0
                end = e ?? d
            default : break
            }
        
            var st = min(time, end-1 )
            st = max(st, 0) + start
            if !player.seek(st) { self.onPlayerError(playerError: .illegalState(.seek(time: time, andPlay: play)))}
            self.onSeek(time: st, isAfterplay: play)
        }
                
    }
    
    func onPlayerBecomeActive() {
    }
    
    func onPlayerPersistKeyReady(contentId:String? , ckcData:Data? = nil) {
        self.onPersistKeyReady(contentId:contentId, ckcData: ckcData)
        
    }
    func onPlayerAssetInfo(_ info:GOVPlayer.AssetPlayerInfo) {
        self.setAssetInfo(info)
        
    }
    
    func onPlayerSubtltle(_ langs: [GOVPlayer.LangType]) {
        self.setSubtltle(langs)
    }
    
    func onPlayerCompleted(){
        self.onCompleted()
    }

    func onPlayerError(streamError error:GOVPlayer.StreamError){
        self.onPaused()
        self.onError(error)
    }
    
    func onPlayerError(playerError:GOVPlayer.PlayerError){
        self.onError(playerError)
    }
    
    func onPlayerVolumeChanged(_ v:Float){
        if self.viewModel.volume == -1 {
            self.onVolumeChange(v)
            return
        }
        if self.viewModel.volume == v {return}
        self.onVolumeChange(v)
        if self.viewModel.isMute && v != 0 {
            self.viewModel.excute(.mute(false))
        } else if !self.viewModel.isMute && v == 0 {
            self.viewModel.excute(.mute(true))
        }
    }
    func onPlayerBitrateChanged(_ bitrate: Double) {
        self.onBitrateChanged(bitrate)
    }
    func onPlayerTimeChange(_ playerController: GOVAVPlayerController, t:CMTime){
        let t = CMTimeGetSeconds(t)
        self.timeChange(playerController, t: Double(t))
        
    }
    private func timeChange(_ playerController: GOVAVPlayerController, t:Double){
        self.onTimeChange(t)
    }
    
    
    @MainActor
    func onPlayerTimeControlChange(_ playerController: GOVAVPlayerController, status:AVPlayer.TimeControlStatus){
        switch status {
        case .paused:
            self.onPaused()
            if let t = playerController.govPlayer.player?.currentTime().seconds {
                self.timeChange(playerController, t: t+1)
            }
                
        case .playing:
            if let t = playerController.govPlayer.player?.currentTime().seconds {
                self.onTimeChange(t)
            }
            self.onResumed()
        case .waitingToPlayAtSpecifiedRate:
            DispatchQueue.main.async {self.onBuffering(rate: 0.0)}
        default:break
        }
    }
    func onPlayerStatusChange(_ playerController: GOVAVPlayerController, status:AVPlayer.Status){
        switch status {
        case .failed:
            self.onPlayerError(streamError: .playback("failed"))
            
        case .unknown:break
        case .readyToPlay:
            self.onReadyToPlay()
        default:break
        }
    }
    func onReasonForWaitingToPlay(_ playerController: GOVAVPlayerController, reason:AVPlayer.WaitingReason){
        switch reason {
        case .evaluatingBufferingRate:
            self.onBuffering(rate: 0.0)
        case .noItemToPlay:
            self.onBuffering(rate: 0.0)
        case .toMinimizeStalls:
            self.onToMinimizeStalls()
        default:break
        }
    }
    
    @MainActor
    func onPlayerItemStatusChange(_ playerController: GOVAVPlayerController, status:AVPlayerItem.Status){
        
        switch status {
        case .failed:
            DataLog.d("onPlayerItemStateChange failed" , tag: self.tag)
            self.onPlayerError(streamError: .playback("failed"))
            
        case .unknown:
            DataLog.d("onPlayerItemStateChange unknown" , tag: self.tag)
        
        case .readyToPlay:
            DataLog.d("onPlayerItemStateChange readyToPlay" , tag: self.tag)
            if viewModel.originDuration < 1 {
                self.onReadyToPlayDurationCheck(playerController)
            }
            self.onReadyToPlay()
             
        default:break
        }
    }
    
    @MainActor
    private func onReadyToPlayDurationCheck(_ playerController: GOVAVPlayerController) {
        if let player = playerController.govPlayer.player {
            Task {
                if let d = try await player.currentItem?.asset.load(.duration) {
                    self.setRemoteAction()
                    let willDuration = Double(CMTimeGetSeconds(d))
                    if willDuration > 0 {
                        DispatchQueue.main.async {
                            self.onDurationChange(willDuration)
                           self.setRemoteActionSeekAble()
                            playerController.govPlayer.playInit(duration: willDuration)
                        }
                    } else {
                        DispatchQueue.main.async {
                            playerController.govPlayer.playInit()
                        }
                    }
                }
                
            }
        }
    }
    
    @MainActor
    func setRemoteAction(){
        DataLog.d("setRemoteAction", tag:self.tag)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.addTarget(handler: self.onRemoteTogglePlay)
        commandCenter.playCommand.addTarget(handler: self.onRemoteResume)
        commandCenter.pauseCommand.addTarget(handler: self.onRemotePause)
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value:-GOVPlayer.seekMoveDefaultValue)]
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value:GOVPlayer.seekMoveDefaultValue)]
        commandCenter.skipBackwardCommand.addTarget(handler: self.onRemoteSkipBackward)
        commandCenter.skipForwardCommand.addTarget(handler: self.onRemoteSkipForward)
        commandCenter.changePlaybackPositionCommand.addTarget(handler: self.onRemoteChangePlaybackPosition)
    }
    
    @MainActor
    func removeRemoteAction(){
        DataLog.d("removeRemoteAction", tag:self.tag)
        self.setRemoteActionSeekAble(false)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(self.onRemoteTogglePlay)
        commandCenter.playCommand.removeTarget(self.onRemoteResume)
        commandCenter.pauseCommand.removeTarget(self.onRemotePause)
        commandCenter.skipBackwardCommand.preferredIntervals.removeAll()
        commandCenter.skipForwardCommand.preferredIntervals.removeAll()
        commandCenter.skipBackwardCommand.removeTarget(self.onRemoteSkipBackward)
        commandCenter.skipForwardCommand.removeTarget(self.onRemoteSkipForward)
        commandCenter.changePlaybackPositionCommand.removeTarget(self.onRemoteChangePlaybackPosition)
    }
    @MainActor
    func onRemoteTogglePlay(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.viewModel.excute(.togglePlay)
        return MPRemoteCommandHandlerStatus.success
    }
    @MainActor
    func onRemoteResume(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.viewModel.excute(.resume)
        return MPRemoteCommandHandlerStatus.success
    }
    @MainActor
    func onRemotePause(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.viewModel.excute(.pause)
        return MPRemoteCommandHandlerStatus.success
    }
    @MainActor
    func onRemoteSkipBackward(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.viewModel.excute(.seekMove(-GOVPlayer.seekMoveDefaultValue, andPlay: nil))
        return MPRemoteCommandHandlerStatus.success
    }
    @MainActor
    func onRemoteSkipForward(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.viewModel.excute(.seekMove(GOVPlayer.seekMoveDefaultValue, andPlay: nil))
        return MPRemoteCommandHandlerStatus.success
    }
    @MainActor
    func onRemoteChangePlaybackPosition(_ evt:MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        let seconds = (evt as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0
        self.viewModel.excute(.seek(time: seconds, andPlay: nil))
        return MPRemoteCommandHandlerStatus.success
    }
    
    func setRemoteActionSeekAble(_ able:Bool? = nil){
        guard let allow = able ?? self.viewModel.allowSeeking else {return}
        DataLog.d("setRemoteActionSeekAble " + allow.description, tag:"commandCenter")
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.changePlaybackPositionCommand.isEnabled = allow
        commandCenter.togglePlayPauseCommand.isEnabled = allow
        commandCenter.pauseCommand.isEnabled = allow
        commandCenter.playCommand.isEnabled = allow
        commandCenter.skipBackwardCommand.isEnabled = allow
        commandCenter.skipForwardCommand.isEnabled = allow
        commandCenter.seekForwardCommand.isEnabled = allow
        commandCenter.seekBackwardCommand.isEnabled = allow
    }
}


struct GOVAVPlayerRepresentable: @preconcurrency GOVPlayBack {
    var viewModel: GOVPlayer.ViewModel
    func makeCoordinator() -> Coordinator { return Coordinator() }
    class Coordinator:NSObject, AVPlayerViewControllerDelegate, GOVPlayerProtocol {
        /*
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator){
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator){
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController){
            DataLog.d("playerViewControllerWillStartPictureInPicture" , tag: self.tag)
        }

        func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController){
            DataLog.d("playerViewControllerDidStartPictureInPicture" , tag: self.tag)
        }
        
        func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error){
            DataLog.d("playerViewController failedToStartPictureInPictureWithError" , tag: self.tag)
        }

        func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController){
            DataLog.d("playerViewControllerWillStopPictureInPicture" , tag: self.tag)
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController){
            DataLog.d("playerViewControllerDidStopPictureInPicture" , tag: self.tag)
        }

        func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool{
            DataLog.d("playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart" , tag: self.tag)
            return false
        }
        
        func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
                                    @escaping (Bool) -> Void){
            DataLog.d("crestoreUserInterfaceForPictureInPictureStopWithCompletionHandler" , tag: self.tag)
        }
        */
    }
}
