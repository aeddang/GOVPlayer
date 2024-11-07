//
//  Error.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//

import Foundation
import SwiftUI
import AVKit

extension GOVPlayer{
    public enum PlayerError{
        case connect(String), stream(StreamError),
             illegalState(Request), drm(FairPlayError), asset(AssetLoadError)
        
        func getDescription() -> String {
            switch self {
            case .connect(let path):
                return "Connect Error " + path
            case .stream:
                return "Stream Error " + self.getDescription()

            case .illegalState :
                return "IllegalState Error"
            case .drm(let e):
                return "Drm Error " + e.getDescription()
            case .asset(let e) :
                return "Asset Error " + e.getDescription()
            }
        }
    }
    public enum StreamError:Error{
        case playback(String),
             pip(String),
             certification(String),
             network,
             unknown(String)
        
        func getDescription() -> String {
            switch self {
            case .pip(let s):
                return "PlayerStreamError pip " + s
            case .playback(let s):
                return "PlayerStreamError playback " + s
          
            case .certification(let s):
                return "PlayerStreamError certification " + s
            case .unknown(let s):
                return "PlayerStreamError unknown " + s
            case .network :
                return "PlayerStreamError network "
            }
        }
    }
}
