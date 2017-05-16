//
//  UIColorExtensions.swift
//  browse
//
//  Created by Evan Brooks on 5/15/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

public extension UIColor
{
    func isLight() -> Bool {
        let components : Array<CGFloat> = self.cgColor.components!
        
        if components.count < 3 { return true }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return (r * 299 + g * 587 + b * 114 ) < 700
    }
    
    static func average(_ colors : Array<UIColor>) -> UIColor {
        let components : Array<Array<CGFloat>> = colors.map { $0.cgColor.components! }
        
        let count = CGFloat(colors.count)
        let r = ( components.reduce(0) { $0 + $1[0] } ) / count
        let g = ( components.reduce(0) { $0 + $1[1] } ) / count
        let b = ( components.reduce(0) { $0 + $1[2] } ) / count
        let a = ( components.reduce(0) { $0 + $1[3] } ) / count
        
        let avgColor = CGColor(colorSpace: colors[0].cgColor.colorSpace!, components: [r,g,b,a])!
        
        return UIColor(cgColor: avgColor)
    }
        
    func darken(_ amount : CGFloat) -> UIColor {
        let components : Array<CGFloat> = self.cgColor.components!
        
        if components.count < 3 { return self }
        
        let r = components[0] * amount
        let g = components[1] * amount
        let b = components[2] * amount
        
        let avgColor = CGColor(colorSpace: self.cgColor.colorSpace!, components: [r,g,b,1])!
        
        return UIColor(cgColor: avgColor)
    }
    
    // http://www.sthoughts.com/2015/11/16/swift-2-1-uicolor-calculating-color-and-brightness-difference/
    func difference(from otherColor: UIColor) -> Float {
        
        let components1 : Array<CGFloat> = self.cgColor.components!
        let components2 : Array<CGFloat> = otherColor.cgColor.components!
        if components1.count < 3 {
            print("Self isn't RGB: \(self)")
            return 0
        }
        if components2.count < 3 {
            print("Other isn't RGB: \(otherColor)")
            return 0
        }


        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = (max(r1, r2) - min(r1, r2))
        let g = (max(g1, g2) - min(g1, g2))
        let b = (max(b1, b2) - min(b1, b2))
        
        return Float(r + g + b)
    }
    
}
