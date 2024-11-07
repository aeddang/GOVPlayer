//
//  LangType.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/31/24.
//
import SwiftUI
import Foundation
extension GOVPlayer{
    
    
    struct Caption{
        var lang:LangType? = nil
        var size:CGFloat = 130
        var color:Color = Color.white
    }
    
    enum LangType:String, CaseIterable{
        case ko, en, ja, zh, vi, ru, ms, id, tl, th, hi, notUsed
        var decription: String {
            switch self {
            case .ko: return "한국어"
            case .en: return "영어"
            case .ja: return "일본어"
            case .zh: return "중국어"
            case .vi: return "베트남어"
            case .ru: return "러시아어"
            case .ms: return "말레이어"
            case .id: return "인도네시아어"
            case .tl: return "필리핀어"
            case .th: return "태국어"
            case .hi: return "인도어"
            case .notUsed: return "사용 안 함"
            }
        }
        
        var logValue: String {
            switch self {
            case .notUsed: return "off"
            default : return self.rawValue
            }
        }

        static func getType(_ value:String?)->LangType{
            switch value {
            case "ko": return .ko
            case "en": return .en
            case "ja": return .ja
            case "zh": return .zh
            case "vi": return .vi
            case "ru": return .ru
            case "ms": return .ms
            case "id": return .id
            case "tl": return .tl
            case "th": return .th
            case "hi": return .hi
            default : return .notUsed
            }
        }
    }
}
