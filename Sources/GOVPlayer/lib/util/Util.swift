//
//  Util.swift
//  GOVPlayer
//
//  Created by JeongCheol Kim on 10/29/24.
//
import SwiftUI
import UIKit
import CryptoKit

extension String{
    func toPercentEncoding()-> String {
        var chSet = CharacterSet.alphanumerics
        chSet.insert(charactersIn: "-._*")
        return self.addingPercentEncoding(withAllowedCharacters: chSet)?.replace(" ", with: "+") ?? self
    }
    func replace(_ originalString:String, with newString:String) -> String {
        return self.replacingOccurrences(of: originalString, with: newString)
    }
    func toFixLength(_ l:Int, prefix:String = "000000") -> String {
        if self.count >= l { return self }
        let fix:String = prefix + self
        return String(fix.suffix(l))
    }
}
extension Double {
    func toInt() -> Int {
        if self >= Double(Int.min) && self < Double(Int.max) {
            return Int(self)
        } else {
            return 0
        }
    }
    
    func secToHourString(_ div:String = ":", fix:Int = 2) -> String {
        let ts = self.toInt()
        if ts < 0 {return "00:00"}
        let sec = ts % 60
        
        let min = floor( Double(self / 60) ).toInt() % 60
        if self < 3600 {
            return min.description.toFixLength(fix) + div + sec.description.toFixLength(fix)
        }
        let hour = floor( Double(self / 3600) ).toInt()
        return hour.description + div + min.description.toFixLength(fix) + div + sec.description.toFixLength(fix)
    }
    
    func toDate() -> Date {
        return Date(timeIntervalSince1970: self)
    }
}
extension Date {
    func toDateFormatter(dateFormat:String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                         local:String="en_US_POSIX", timeZone:TimeZone? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: local) // set locale to reliable US_POSIX
        dateFormatter.dateFormat = dateFormat
        dateFormatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: NSTimeZone.local.secondsFromGMT())
        return dateFormatter.string(from:self)
    }
}
