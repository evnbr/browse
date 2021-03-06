//
//  UIColorExtensions.swift
//  browse
//
//  Created by Evan Brooks on 5/15/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

public extension UIColor {
    static let lightOverlay = UIColor.white.withAlphaComponent(0.2)
    static let darkOverlay = UIColor.white.withAlphaComponent(0.08)

    static let darkTouch = UIColor.black.withAlphaComponent(0.1)
    static let lightTouch = UIColor.white.withAlphaComponent(0.25)
    
    static let darkField = UIColor.black.withAlphaComponent(0.08)
    static let lightField = UIColor.white.withAlphaComponent(0.12)

    convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    func rgbComponents() -> [ CGFloat ] {
        if let name: CFString = self.cgColor.colorSpace?.name {
            let components: [ CGFloat ] = self.cgColor.components
            if components.count == 4 {
                return components
            } else if name == CGColorSpace.extendedGray && components.count == 2 {
                let gray = components[0]
                return [gray, gray, gray, 1]
            }
            print("unkonwn name: \(name), components: \(components.count)")
            return [0, 0, 0, 1]
        }
        print("no name")
        return [0, 0, 0, 1]
    }

    var isLight: Bool {
        let components = self.cgColor.components //self.getRGB()

        let r = components[0]
        let g = components[1]
        let b = components[2]

        return (r * 299 + g * 587 + b * 114 ) < 700
    }

    var withSecondaryAlpha: UIColor {
        return self.withAlphaComponent(self.isLight ? 0.4 : 0.6)
    }

    static func average(_ colors: UIColor...) -> UIColor {
        return self.average(colors)
    }

    static func average(_ colors: [ UIColor ]) -> UIColor {
        let count = CGFloat(colors.count)
        let allComponents: [[ CGFloat ]] = colors.map { $0.rgbComponents() }

        let r = ( allComponents.reduce(0) { $0 + $1[0] }) / count
        let g = ( allComponents.reduce(0) { $0 + $1[1] }) / count
        let b = ( allComponents.reduce(0) { $0 + $1[2] }) / count
        
        return UIColor(r: r, g: g, b: b)
    }

    func withBrightness(_ amount: CGFloat) -> UIColor {
        var h = CGFloat()
        var s = CGFloat()
        var b = CGFloat()
        var a = CGFloat()

        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return UIColor(hue: h, saturation: s, brightness: min(1, max(b * amount, 0)), alpha: a)
    }

    func saturated() -> UIColor {
        var h = CGFloat()
        var s = CGFloat()
        var b = CGFloat()
        var a = CGFloat()

        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        return UIColor(hue: h, saturation: 1, brightness: 0.5, alpha: a)
    }

    // http://www.sthoughts.com/2015/11/16/swift-2-1-uicolor-calculating-color-and-brightness-difference/
    func difference(from otherColor: UIColor) -> Float {
        let components1: [ CGFloat ] = self.rgbComponents()
        let components2: [ CGFloat ] = otherColor.rgbComponents()
        if components1.count < 3 {
            print("Self isn't RGB: \(self)")
            return 0
        }
        if components2.count < 3 {
            print("Other isn't RGB: \(otherColor)")
            return 0
        }

        let r1: CGFloat = components1[0]
        let g1: CGFloat = components1[1]
        let b1: CGFloat = components1[2]

        let r2: CGFloat = components2[0]
        let g2: CGFloat = components2[1]
        let b2: CGFloat = components2[2]

        let r = (max(r1, r2) - min(r1, r2))
        let g = (max(g1, g2) - min(g1, g2))
        let b = (max(b1, b2) - min(b1, b2))

        return Float(r + g + b)
    }

}
