//
//  Timer.swift
//  MyTVFramework
//
//  Created by JeongCheol Kim on 2023/07/20.
//

import Foundation
import Combine

class ScheduleExcutor: ObservableObject{
    private(set) var excutor:AnyCancellable? = nil
    private(set) var isReservation:Bool = false
    private(set) var sceduleDelay:Double? = nil
    private(set) var sceduleLoop:RunLoop.Mode? = nil
    private(set) var sceduleAction:((Int) -> Void)? = nil
    func reservation(delay:Double, loop:RunLoop.Mode = .common,_ action:@escaping () -> Void){
        self.excutor?.cancel()
        self.isReservation = true
        self.excutor = Timer.publish(
            every:delay, on: .current, in: loop)
            .autoconnect()
            .sink() {_ in
                self.cancel()
                action()
            }
    }
    
    @discardableResult
    func sceduleRestart()->Bool{
        guard let delay = self.sceduleDelay , let loop = sceduleLoop, let action = sceduleAction else {return false}
        self.scedule(delay: delay, loop:loop, action)
        return true
    }
    func resume(){
        self.sceduleRestart()
    }
    func pause(){
        self.excutor?.cancel()
    }
    
    func scedule(delay:Double, loop:RunLoop.Mode = .common ,_ action:@escaping (Int) -> Void){
        self.excutor?.cancel()
        self.sceduleLoop = loop
        self.sceduleDelay = delay
        self.sceduleAction = action
        var count = 0
        self.excutor = Timer.publish(
            every:delay, on: .current, in: loop)
            .autoconnect()
            .sink() {_ in
                action(count)
                count += 1
            }
    }
    
    func cancel(){
        self.excutor?.cancel()
        self.excutor = nil
        self.sceduleLoop = nil
        self.sceduleDelay = nil
        self.sceduleAction = nil
        self.isReservation = false
    }
}



