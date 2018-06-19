//
//  KeyboardManager.swift
//  browse
//
//  Created by Evan Brooks on 6/18/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class KeyboardManager: NSObject {
    private var snapshot: UIImage?
    private var lastKeyboardSize: CGSize?
    private var lastKeyboardColor: UIColor?
    
    var height : CGFloat = 250
    
    private func takeKeyboardSnapshot(size: CGSize) -> UIImage? {
        let screen = UIScreen.main.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.translateBy(x: 0, y: -(screen.height - height))
        
        for window in UIApplication.shared.windows {
            if (window.screen == UIScreen.main) {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false) // if true, weird flicker
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return img
    }
    
    func snapshot(for backgroundColor: UIColor) -> UIImage? {
        if backgroundColor.isLight {
            return snapshot;
        } else {
            return snapshot;
        }
    }
    
    func updateSnapshot(with backgroundColor: UIColor?) {
        let screen = UIScreen.main.bounds.size
        let kbSize = CGSize(width: screen.width, height: height)
        if backgroundColor != lastKeyboardColor || kbSize != lastKeyboardSize {
            snapshot = takeKeyboardSnapshot(size: kbSize)
            lastKeyboardSize = kbSize
            lastKeyboardColor = backgroundColor
        }
    }
}
