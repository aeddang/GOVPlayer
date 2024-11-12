//
//  Event.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//

import Foundation
import SwiftUI
import AVKit

extension GOVPlayer{
    
    public enum UIRequest {//input
        case change(UIState), stay(UIState)
    }
    
    public enum UIState :Equatable{
        case view, hidden
        public var isShowing:Bool{
            switch self {
            case .view : return true
            default : return false
            }
        }
        
        public static func == (l:UIState, r:UIState)-> Bool {
            switch (l, r) {
            case ( .view, .view):return true
            case ( .hidden, .hidden):return true
            default: return false
            }
        }
    }
    
    
    public enum Request {//input
        case load(path:String, autoPlay:Bool = true, initTime:Double = 0.0),
             togglePlay,
             resume,
             pause,
             stop,
             volume(Float),
             rate(Float),
             mute(Bool),
             seek(time:Double, andPlay:Bool? = nil),
             seekProgress(Float, andPlay:Bool? = nil),
             seekMove(Double, andPlay:Bool? = nil),
             screenGravity(AVLayerVideoGravity),
             screenRatio(CGFloat),
             captionChange(
                lang:String? = nil, size:CGFloat? = nil ,
                color:Color? = nil, position:CGFloat? = nil
             ),
             pip(Bool), usePip(Bool),
             next, prev
        
    }
    
    
    public enum StreamEvent {
        case persistKeyReady(String?, Data?),
             resumed,
             paused,
             loaded(String),
             buffer,
             stoped,
             seeked,
             completed,
             pipClosed(Bool),
             next,
             playEvent(String),
             timeRangeCompleted,
             sectionPlayCompleted,
             sectionPlayNext(Int)
    }
    
    public enum State :Equatable{
        case load, resume, pause,
             seek(Double, isPrevPlay:Bool, isAfterPlay:Bool?),
             complete, error, stop
        
        public var isPlay:Bool{
            switch self {
            case .complete, .error, .stop, .load : return false
            default : return true
            }
        }
        public var isPlaying:Bool{
            switch self {
            case .resume : return true
            default : return false
            }
        }
        
        public var isStreaming:Bool{
            switch self {
            case .error, .stop : return false
            default : return true
            }
        }
        public static func == (l:State, r:State)-> Bool {
            switch (l, r) {
            case ( .load, .load):return true
            case ( .resume, .resume):return true
            case ( .pause, .pause):return true
            case ( .seek, .seek):return true
            case ( .complete, .complete):return true
            case ( .error, .error):return true
            case ( .stop, .stop):return true
            default: return false
            }
        }
    }
    
    public enum StreamState :Equatable{
        case buffering(Double), playing, stop
        public var isStreamimg:Bool{
            switch self {
            case .playing, .buffering : return true
            default : return false
            }
        }
        public var isLoading:Bool{
            switch self {
            case .buffering : return true
            default : return false
            }
        }
        public static func == (l:StreamState, r:StreamState)-> Bool {
            switch (l, r) {
            case ( .buffering, .buffering):return true
            case ( .playing, .playing):return true
            case ( .stop, .stop):return true
            default: return false
            }
        }
    }
    
    public enum Mode :Equatable{
        case vod,
             section(start:Double? = nil, end:Double? = nil),
             live(start:Double? = nil, end:Double? = nil)  // timestamp
        public var isLive:Bool{
            switch self {
            case .live : return true
            default : return false
            }
        }
        public static func == (l:Mode, r:Mode)-> Bool {
            switch (l, r) {
            case ( .vod, .vod):return true
            case ( .section, .section):return true
            case ( .live, .live):return true
            default: return false
            }
        }
    }
    
    public enum PipState:String {
        case on, off
    }
}
