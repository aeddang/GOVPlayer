//
//  FairPlayDrm.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//
import Foundation
import SwiftUI
extension GOVPlayer{
    public class FairPlayDrm{
        let ckcURL:String
        let certificateURL:String
        var contentId:String? = nil
        var useOfflineKey:Bool = false
        var certificate:Data? = nil
        var isCompleted:Bool = false
        var persistKeys:[(String,Data,Date)] = []
        init( ckcURL:String,
              certificateURL:String) {
            
            self.ckcURL = ckcURL
            self.certificateURL = certificateURL
            
        }
        init( persistKeys:[(String,Data,Date)]) {
            self.ckcURL = ""
            self.certificateURL = ""
            self.persistKeys = persistKeys
            self.useOfflineKey = true
        }
    }
    
    public enum FairPlayError: Error {
        case certificate(reason:String)
        case contentId(reason:String)
        case spcData(reason:String)
        case ckcData(reason:String)
        case stream
        
        func getDescription() -> String {
            switch self {
            case .certificate(let reason):
                return "certificate error " + reason
            case .spcData(let reason):
                return "spcData error " + reason
            case .contentId(let reason):
                return "contentId error " + reason
            case .ckcData(let reason):
                return "ckcData error " + reason
            case .stream:
                return "stream error"
            }
        }
        
        func getDomain() -> String {
            return "drm"
        }
        
        func getCode() -> Int {
            return -3
        }
    }
}
