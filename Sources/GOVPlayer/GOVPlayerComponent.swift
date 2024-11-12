import Foundation
import SwiftUI
import Combine
import MediaPlayer

extension GOVPlayer{
    open class UIViewModel: ObservableObject, GOVPlayerProtocol {
        @Published fileprivate(set) var request:UIRequest? = nil{
            didSet{
                if request != nil { self.request = nil }
            }
        }
        @Published fileprivate(set) var state:UIState = .hidden
        
        @Published fileprivate(set) var time:String? = nil
        @Published fileprivate(set) var remainingTime:String = "0:00:00"
        @Published fileprivate(set) var duration:String = "0:00:00"
        @Published fileprivate(set) var startTime:String? = nil
        @Published fileprivate(set) var endTime:String? = nil
        @Published fileprivate(set) var progress:Double = 0

        @Published fileprivate(set) var isError = false
        fileprivate(set) var errorMessage:String? = nil
        
        @Published fileprivate(set) var isLoading = false
        @Published fileprivate(set) var isMute = true
        @Published fileprivate(set) var showUI: Bool = false
        @Published fileprivate(set) var showProgress: Bool = false
        @Published fileprivate(set) var isLive:Bool? = nil
        
        @Published fileprivate(set) var useSeek = false
        @Published fileprivate(set) var isSeeking = false
        @Published fileprivate(set) var seekForward:Double? = nil
        @Published fileprivate(set) var seekBackward:Double? = nil
        @Published fileprivate(set) var usePip:Bool = false
        public init(){}
        fileprivate func reset(){
            self.progress = 0
            self.startTime = nil
            self.endTime = nil
            self.seekForward = nil
            self.seekBackward = nil
            self.isLive = nil
        }
        open func initateTimeString(){
            self.remainingTime = "00:00"
            self.duration = "0:00:00"
            self.startTime = nil
            self.endTime = nil
        }
        
        open func getTimeString(_ t:Double) -> String {
            return t.secToHourString()
        }
        open func getTimestampString(_ t:Double) -> String {
            return t.toDate().toDateFormatter(dateFormat: "HH:mm")
        }
    }
    public struct GOVPlayerComponent<Ui>: View, GOVPlayerProtocol where Ui: View {
        
        @EnvironmentObject var viewModel:ViewModel
        @EnvironmentObject var uiModel:UIViewModel
        let ui: Ui
        public init(
            @ViewBuilder content: () -> Ui) {
                self.ui = content()
            }
        
        public var body: some View {
            ZStack(alignment: .center){
                GOVAVPlayerRepresentable(
                    viewModel : self.viewModel
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight:0, maxHeight: .infinity)
                self.ui
            }
            .onReceive(self.viewModel.$streamState) { state in
                self.uiModel.isLoading = state?.isLoading ?? false
            }
            .onReceive(self.viewModel.$playMode) { mode in
                guard let mode = mode else {return}
                self.uiModel.isLive = mode.isLive
                switch mode {
                case .live(let st, let et) :
                    if let t = st {
                        self.uiModel.startTime = self.uiModel.getTimestampString(t)
                    }
                    if let t = et {
                        self.uiModel.endTime = self.uiModel.getTimestampString(t)
                    }
                default : break
                }
            }
            .onReceive(self.viewModel.$allowPip) { allow in
                self.uiModel.usePip = allow ?? false
            }
            .onReceive(self.viewModel.$allowSeeking) { allow in
                self.uiModel.useSeek = allow ?? false
            }
            .onReceive(self.uiModel.$state) { state in
                self.uiModel.showUI = state.isShowing
            }
            
            .onReceive(self.uiModel.$request) { evt in
                guard let evt = evt else { return }
                switch evt {
                case .change(let state):
                    self.uiModel.state = state
                    if state == .hidden {
                        self.autoUiHidden.cancel()
                    } else {
                        self.delayAutoUiHidden()
                    }
                case .stay(let state) :
                    self.uiModel.state = state
                    self.autoUiHidden.cancel()
                    
                }
            }
            .onReceive(self.viewModel.$duration) { d in
                guard let d = d else {return}
                self.uiModel.time = self.uiModel.getTimeString(0)
                self.uiModel.duration = self.uiModel.getTimeString(d)
            }
            .onReceive(self.viewModel.$time) { t in
                self.uiModel.time = self.uiModel.getTimeString(t)
                self.uiModel.progress = self.viewModel.timeProgress
                self.uiModel.remainingTime = self.uiModel.getTimeString(self.viewModel.remainingTime)
            }
            
            .onReceive(self.viewModel.$error) { err in
                guard let err = err else { return }
                var msg = ""
                var code = ""
                switch err {
                case .connect(let s):
                    msg = s
                    code = "#connect error"
                case .stream(let err):
                    msg = err.getDescription()
                    code = "#stream error"
                    
                case .drm(let err):
                    msg = err.getDescription()
                    code = "#drm error"
                case .asset(let err):
                    msg = err.getDescription()
                    code = "#asset error"
                case .illegalState:
                    return
                }
                self.uiModel.errorMessage = msg
                self.uiModel.isError = true
                DataLog.e(code + " : " + msg, tag:self.tag)
                
            }
            .onReceive(self.viewModel.$request) { evt in
                guard let evt = evt else { return }
                switch evt {
                case .seekMove(let t, _):
                    self.uiModel.isSeeking = true
                    if t > 0 {
                        self.uiModel.seekForward = (self.uiModel.seekForward ?? 0) + t
                    } else {
                        self.uiModel.seekBackward = (self.uiModel.seekBackward ?? 0) + abs(t)
                    }
                    self.delayAutoResetSeekMove()
                    
                case .seekProgress, .seek :
                    self.uiModel.isSeeking = true
                default : break
                }
            }
            
            .onReceive(self.viewModel.$streamEvent) { evt in
                guard let evt = evt else { return }
                switch evt {
                case .loaded:
                    self.uiModel.isSeeking = false
                case .paused:
                    self.uiModel.isSeeking = false
                case .resumed:
                    self.uiModel.isSeeking = false
                case .seeked:
                    self.uiModel.isSeeking = false
                case .completed :
                    if self.viewModel.useLoof {
                        self.viewModel.excute(.seek(time:0, andPlay: true))
                    }
                default : break
                }
            }
            .onReceive(self.viewModel.$streamState) { st in
                guard let state = st else { return }
                switch state {
                case .buffering(_) :
                    self.uiModel.isLoading = true
                    //self.networkStatusCheck()
                default :
                    self.uiModel.isLoading = false
                    //self.networkStatusChecker.cancel()
                }
            }
            .onReceive(self.viewModel.$volume){ v in
                if self.viewModel.isMute {
                    self.uiModel.isMute = true
                } else {
                    self.uiModel.isMute = v != 0
                }
            }
            .onReceive(self.viewModel.$isMute){ isMute in
                self.uiModel.isMute = isMute
            }
            .onAppear(){

            }
            .onDisappear(){
                self.autoUiHidden.cancel()
                self.autoResetSeekMove.cancel()
            }
            
        }
        
    
        
        @StateObject private var autoUiHidden = ScheduleExcutor()
        private func delayAutoUiHidden(){
            self.autoUiHidden.cancel()
            if UIAccessibility.isVoiceOverRunning {return}
            self.autoUiHidden.reservation(delay: 3){
                self.uiModel.state = .hidden
                //self.viewModel.request = .captionPositionChange(position: 90)
            }
        }
        
    
        @StateObject private var autoResetSeekMove = ScheduleExcutor()
        private func delayAutoResetSeekMove(){
            self.autoResetSeekMove.reservation(delay: 1){
                self.uiModel.seekForward = nil
                self.uiModel.seekBackward = nil
            }
        }
        /*
        @StateObject private var networkStatusChecker = ScheduleExcutor()
        private func networkStatusCheck(){
            self.networkStatusChecker.reservation(delay: 7){
                if self.networkObserver.isConnected {
                    self.networkStatusCheck()
                } else {
                    self.viewModel.error = .stream(PlayerStreamError.network)
                }
            }
        }
        */
    }
    
}
