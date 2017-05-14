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
    var colorSpace: CGColorSpace!
    var pixel: [CUnsignedChar]

    init(_ wv : WKWebView) {
        webView = wv
        
        pixel = [0, 0, 0, 0]
        colorSpace = CGColorSpaceCreateDeviceRGB();
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

        
        let color = CGColor(colorSpace: colorSpace, components: [
                CGFloat(pixel[0])/255.0,
                CGFloat(pixel[1])/255.0,
                CGFloat(pixel[2])/255.0,
                CGFloat(pixel[3])/255.0,
            ])
        
        let uiColor = UIColor(cgColor: color!)
        return uiColor
    }

    
}
