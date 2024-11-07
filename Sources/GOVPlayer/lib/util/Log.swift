//
//  Log.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/31/24.
//
import Foundation
import os.log

extension GOVPlayerLog {
    static func log(_ message: String, tag:String? = nil , log: OSLog = .default, type: OSLogType = .default) {
        let t = (tag == nil) ? Self.tag : Self.tag + " -> " + tag!
        os_log("%@ %@", log: log, type: type, t, message)
    }
    static func t(_ message: String, tag:String? = nil) {
        Self.d(message, tag: tag)
        
    }
    static func i(_ message: String, tag:String? = nil, lv:Int = 1) {
        if Self.lv < lv {return}
        Self.log(message, tag:tag, log:.default, type:.info )
    }
    
    static func d(_ message: String, tag:String? = nil, lv:Int = 1) {
        
        if Self.lv < lv {return}
        #if DEBUG
        Self.log(message, tag:tag, log:.default, type:.debug )
        #endif
    }
    
    static func e(_ message: String, tag:String? = nil, lv:Int = 1) {
        
        if Self.lv < lv {return}
        Self.log(message, tag:tag, log:.default, type:.error )
    }
}

protocol GOVPlayerLog {
    static var tag:String { get }
    static var lv:Int { get }
}

struct DataLog:GOVPlayerLog {
    static let tag: String = "[GOVPlayer] Data"
    static let lv: Int = 1
}
