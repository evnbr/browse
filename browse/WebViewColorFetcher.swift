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
