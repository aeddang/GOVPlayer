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
}

