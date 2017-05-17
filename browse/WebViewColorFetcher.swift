//
//  WebViewColorFetcher.swift
//  browse
//
//  Created by Evan Brooks on 5/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import WebKit

class WebViewColorFetcher {
    
    var webView: WKWebView!
    var context: CGContext!
    var pixel: [CUnsignedChar]

    init(_ wv : WKWebView) {
        webView = wv
        
        pixel = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
        
    }
        
    func blendColors(_ colors: UIColor...) -> UIColor {
        let average : UIColor = UIColor.average(colors)
        
        // Remove outliers
        let blendable : Array<UIColor> = colors.filter({$0.difference(from: average) < 0.5})
        
        if blendable.count > 1 {

            return UIColor.average(blendable)
        }
        else {
            let distribution : Float = colors.map({$0.difference(from: average)}).reduce(0, +)
            if distribution < Float(colors.count) * 1.0 {
                return average
            }
            for c in colors {
                if c.difference(from: UIColor.white) < 0.3 {
                    return c
                }
            }
            for c in colors {
                if c.difference(from: UIColor.black) < 0.3 {
                    return c
                }
            }
            return UIColor.black
        }
    }
    
    func getColorAtTop() -> UIColor {
        let size = self.webView.bounds.size
        
        let colorAtTopLeft     = getColorAt( x: 5,                y: 1 )
        let colorAtTopRight    = getColorAt( x: size.width - 5,   y: 1 )
        
        return blendColors(colorAtTopLeft, colorAtTopRight)
    }
    
    func getColorAtBottom() -> UIColor {
        let size = self.webView.bounds.size

        let colorAtBottomLeft    = getColorAt( x: 2,                y: size.height - 2 )
        let colorAtBottomRight   = getColorAt( x: size.width - 2,   y: size.height - 2 )
        
        if colorAtBottomLeft.difference(from: colorAtBottomRight) < 1 {
            return blendColors(
                colorAtBottomLeft,
                colorAtBottomRight
            )
        }
        else {
            let colorAtBottomLeftUp  = getColorAt( x: 2,                y: size.height - 24 )
            let colorAtBottomRightUp = getColorAt( x: size.width - 2,   y: size.height - 24 )
            
            return blendColors(
                colorAtBottomLeftUp,
                colorAtBottomLeft,
                colorAtBottomRightUp,
                colorAtBottomRight
            )
        }
    }

    
    func getColorAt(x: CGFloat, y: CGFloat) -> UIColor {
        
        context!.translateBy(x: -x, y: -y )
        
        UIGraphicsPushContext(context!);
        webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: false)
        UIGraphicsPopContext();
        
        context!.translateBy(x: x, y: y ) // Reset transform because context reused

        
        let color = UIColor( colorLiteralRed: Float(pixel[0])/255.0,
                             green:           Float(pixel[1])/255.0,
                             blue:            Float(pixel[2])/255.0,
                             alpha:           Float(pixel[3])/255.0 )
        
        return color
    }

    
}
