//
//  CustomCamera.swift
//  shoppingTrip
//
//  Created by JeongCheol Kim on 2020/07/22.
//  Copyright © 2020 JeongCheol Kim. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import AVKit
import MediaPlayer


protocol GOVAVPlayerControllerDelegate{
    func onPlayerTimeChange(_ playerController: GOVAVPlayerController, t:CMTime)
    func onPlayerTimeControlChange(_ playerController: GOVAVPlayerController, status:AVPlayer.TimeControlStatus)
    func onPlayerStatusChange(_ playerController: GOVAVPlayerController, status:AVPlayer.Status)
    func onPlayerItemStatusChange(_ playerController: GOVAVPlayerController, status:AVPlayerItem.Status)
    func onReasonForWaitingToPlay(_ playerController: GOVAVPlayerController, reason:AVPlayer.WaitingReason)
    func onPlayerVolumeChanged(_ v:Float)
}


protocol GOVAVPlayerController {
    var viewModel:GOVPlayer.ViewModel { get set }
    var govPlayer:GOVPlayer.GOVAVPlayer  { get set }
    var playerDelegate:GOVAVPlayerControllerDelegate  { get set }
    var currentTimeObservser:Any? { get set }
    func run()
    func cancel()
}


extension GOVAVPlayerController {
    func onViewDidAppear(_ animated: Bool) {
        /*
        let id = self.playerScreenView.id
        if CustomAVPlayerController.currentPlayer.first(where: {$0 == id}) == nil {
            CustomAVPlayerController.currentPlayer.append(id)
            if CustomAVPlayerController.currentPlayer.count == 1 {
                UIApplication.shared.beginReceivingRemoteControlEvents()
            }
        }
        */
    }
    func onViewDidDisappear(_ animated: Bool) {
        /*
        let id = self.playerScreenView.id
        if let find = CustomAVPlayerController.currentPlayer.firstIndex(of:id) {
            CustomAVPlayerController.currentPlayer.remove(at: find)
            if CustomAVPlayerController.currentPlayer.isEmpty {
                UIApplication.shared.endReceivingRemoteControlEvents()
            }
        }
        self.cancel()
        self.playerScreenView.destory()
        */
    }
    
    @MainActor
    func onRemoteControlReceived(with event: UIEvent?) {
        guard let type = event?.type else { return}
        if type != .remoteControl { return }
        switch event!.subtype {
        case .remoteControlPause:
            self.viewModel.excute(.pause)
        case .remoteControlPlay:
            self.viewModel.excute(.resume)
        case .remoteControlEndSeekingForward:
            if self.viewModel.isSeekAble == false {return}
            self.viewModel.excute(.seekMove(-15))
        case .remoteControlEndSeekingBackward:
            if self.viewModel.isSeekAble == false {return}
            self.viewModel.excute(.seekMove(15))
        case .remoteControlNextTrack:
            self.viewModel.excute(.next)
        case .remoteControlPreviousTrack:
            self.viewModel.excute(.prev)
        default: break
        }
    }
    func onPlayerItemStatusChange(_ playerController: GOVAVPlayerController, Status:AVPlayerItem.Status){}
    func onReasonForWaitingToPlay(_ playerController: GOVAVPlayerController, reason:AVPlayer.WaitingReason){}
    

    func onTimeChange(_ t:CMTime) {
        self.playerDelegate.onPlayerTimeChange(self, t:t)
    }
    

    func onStatusChange(_ keyPath: String?, change: [NSKeyValueChangeKey : Any]?) {
        switch keyPath {
        case #keyPath(AVPlayer.status) :
            if let num = change?[.newKey] as? Int {
                self.playerDelegate.onPlayerStatusChange(self, status: AVPlayer.Status(rawValue: num) ?? .unknown)
            } else {
                self.playerDelegate.onPlayerStatusChange(self, status: .unknown)
            }
        case #keyPath(AVPlayer.currentItem.status) :
            if let num = change?[.newKey] as? Int {
                self.playerDelegate.onPlayerItemStatusChange(self, status: AVPlayerItem.Status(rawValue: num) ?? .unknown)
            } else {
                self.playerDelegate.onPlayerItemStatusChange(self, status: .unknown)
            }
        case #keyPath(AVPlayer.timeControlStatus) :
            if let num = change?[.newKey] as? Int,
               let Status = AVPlayer.TimeControlStatus(rawValue: num) {
                self.playerDelegate.onPlayerTimeControlChange(self, status: Status)
            }
        case #keyPath(AVPlayer.reasonForWaitingToPlay) :
            if let str = change?[.newKey] as? String{
                let reason = AVPlayer.WaitingReason(rawValue: str)
                self.playerDelegate.onReasonForWaitingToPlay(self, reason: reason)
            }
        case "outputVolume" :
            let audioSession = AVAudioSession.sharedInstance()
            let volume = audioSession.outputVolume
            DataLog.d("systemVolume changed " + volume.description, tag: "AVAudioSession")
            self.playerDelegate.onPlayerVolumeChanged(volume)
            
        default : break
        }
    }
}


open class CustomPlayerViewController: UIViewController,
                                       @preconcurrency GOVAVPlayerController ,
                                       @preconcurrency GOVAVPlayerRunningDelegate{
    var playerDelegate: GOVAVPlayerControllerDelegate
    var govPlayer: GOVPlayer.GOVAVPlayer
    var viewModel:GOVPlayer.ViewModel
    var currentTimeObservser:Any? = nil
    
    init(viewModel:GOVPlayer.ViewModel, player:GOVPlayer.GOVAVPlayer, playerDelegate: GOVAVPlayerControllerDelegate) {
        self.viewModel = viewModel
        self.govPlayer = player
        self.playerDelegate = playerDelegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var canBecomeFirstResponder: Bool { return true }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.onViewDidAppear(animated)
        self.becomeFirstResponder()
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.onViewDidDisappear(animated)
        self.resignFirstResponder()
    }
         
    open override func remoteControlReceived(with event: UIEvent?) {
        self.onRemoteControlReceived(with: event)
    }
    
    func onPlayerReady() {
        self.run()
    }
    
    func onPlayerDestory() {
        self.cancel() 
    }
    
    func run(){
        guard let player = self.govPlayer.player else {return}
        self.currentTimeObservser = player.addPeriodicTimeObserver(
            forInterval: CMTimeMakeWithSeconds(1,preferredTimescale: Int32(NSEC_PER_SEC)),
            queue: DispatchQueue.main){ [weak self] time in
                guard let self = self else {return}
                self.onTimeChange(time)
        }
        //player.addObserver(self, forKeyPath: #keyPath(AVPlayer.Status), options: [.new], context: nil)
        //player.addObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay), options: [.new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[NSKeyValueObservingOptions.new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options:[NSKeyValueObservingOptions.new], context: nil)
        AVAudioSession.sharedInstance()
            .addObserver(self, forKeyPath: "outputVolume" , options: NSKeyValueObservingOptions.new, context: nil)
         
    }
    func cancel() {
        guard let player = self.govPlayer.player else {return}
        guard let currentTimeObservser = self.currentTimeObservser else {return}
        player.removeTimeObserver(currentTimeObservser)
        //player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.Status))
        //player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume" )
        self.currentTimeObservser = nil
    }
    
    open override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?){
            self.onStatusChange(keyPath, change: change)
    }
    
}

//기본UI
open class CustomAVPlayerViewController: AVPlayerViewController,
                                         @preconcurrency GOVAVPlayerController ,
                                         @preconcurrency GOVAVPlayerRunningDelegate {
    var playerDelegate: GOVAVPlayerControllerDelegate
    var govPlayer: GOVPlayer.GOVAVPlayer
    var viewModel:GOVPlayer.ViewModel
    var currentTimeObservser:Any? = nil
   
    init(viewModel:GOVPlayer.ViewModel, player:GOVPlayer.GOVAVPlayer, playerDelegate: GOVAVPlayerControllerDelegate) {
        self.viewModel = viewModel
        self.govPlayer = player
        self.playerDelegate = playerDelegate
        super.init(nibName: nil, bundle: nil)
    }
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    open override var canBecomeFirstResponder: Bool { return true }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.onViewDidAppear(animated)
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.onViewDidDisappear(animated)
    }
    open override func remoteControlReceived(with event: UIEvent?) {
        self.onRemoteControlReceived(with: event)
    }
    func onPlayerReady() {
        self.run()
    }
    func onPlayerDestory() {
        self.cancel()
    }
    
    func run(){
        guard let player = self.govPlayer.player else {return}
        self.currentTimeObservser = player.addPeriodicTimeObserver(
            forInterval: CMTimeMakeWithSeconds(1,preferredTimescale: Int32(NSEC_PER_SEC)),
            queue: DispatchQueue.main){ [weak self] time in
                guard let self = self else {return}
                self.onTimeChange(time)
                
        }
        //player.addObserver(self, forKeyPath: #keyPath(AVPlayer.Status), options: [.new], context: nil)
        //player.addObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay), options: [.new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status),
                           options:[NSKeyValueObservingOptions.new], context: nil)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus),
                           options:[NSKeyValueObservingOptions.new], context: nil)
        AVAudioSession.sharedInstance()
            .addObserver(self, forKeyPath: "outputVolume" , options: NSKeyValueObservingOptions.new, context: nil)
         
    }
    func cancel() {
        guard let player = self.govPlayer.player else {return}
        guard let currentTimeObservser = self.currentTimeObservser else {return}
        player.removeTimeObserver(currentTimeObservser)
        //player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.Status))
        //player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status))
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume" )
        self.currentTimeObservser = nil
    }
    
    open override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?){
            self.onStatusChange(keyPath, change: change)
            
    }
}





extension MPVolumeView {
    static func moveVolume(_ move: Float) -> Void {
        let volumeView = MPVolumeView(frame: .zero)
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
       
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            guard let prev = slider else {return}
            let preV = prev.value
            DataLog.d("prev " + preV.description, tag:"MPVolumeView")
            DataLog.d("move " + move.description, tag:"MPVolumeView")
            let v = preV + move
            prev.value = v
        }
    }
    static func setVolume(_ volume: Float) -> Void {
        let volumeView = MPVolumeView(frame: .zero)
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
            DataLog.d("slider " + volume.description, tag:"MPVolumeView")
        }
        
    }
}
