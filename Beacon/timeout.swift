//
//  timeout.swift
//  Beacon
//
//  Created by SSLAB on 2017/5/31.
//  Copyright © 2017年 SSLAB. All rights reserved.
//

import Foundation

/// Timeout wrapps a callback deferral that may be cancelled.
///
/// Usage:
/// Timeout(1.0) { println("1 second has passed.") }
///
class Timeout: NSObject
{
    private var timer: Timer?
    private var callback: ((Void) -> Void)?
    
    init(_ delaySeconds: Double, _ callback: () -> ())
    {
        super.init()
        self.callback = callback
        self.timer = Timer.scheduledTimer(timeInterval: delaySeconds, target: self, selector: "invoke", userInfo: nil, repeats: false)
    }
    
    func invoke()
    {
        self.callback?()
        // Discard callback and timer.
        self.callback = nil
        self.timer = nil
    }
    
    func cancel()
    {
        self.timer?.invalidate()
        self.timer = nil
    }
}
