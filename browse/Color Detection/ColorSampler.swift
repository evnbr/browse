//
//  ColorSampler.swift
//  browse
//
//  Created by Evan Brooks on 5/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import WebKit

extension ClosedRange {
    func clamp(_ value : Bound) -> Bound {
        return self.lowerBound > value ? self.lowerBound
            : self.upperBound < value ? self.upperBound
            : value
    }
    
}

enum ColorTransitionStyle {
    case fade
    case translate
}

let DURATION = 1.0
let MIN_TIME_BETWEEN_UPDATES = 0.15

class ColorSampler : NSObject, UIGestureRecognizerDelegate {
        
    private var colorUpdateTimer : Timer?

    var webView: WKWebView!
    
    private var isTopAnimating : Bool = false
    private var isBottomAnimating : Bool = false
    private var isPanning : Bool = false
    private var wasScrollingDown : Bool = true
    
    private var isBottomTransitionInteractive = false
    private var isTopTransitionInteractive = false

    private var context: CGContext!
    private var pixel: [CUnsignedChar]
    
    public var top: UIColor = UIColor.clear
    public var bottom: UIColor = UIColor.clear
    
    public var previousTop: UIColor = UIColor.clear
    public var previousBottom: UIColor = UIColor.clear
    
    public var topDelta: Float = 0.0
    public var bottomDelta: Float = 0.0
    
    var lastSampledColorsTime : CFTimeInterval = 0.0
    var lastTopTransitionTime : CFTimeInterval = 0.0
    var lastBottomTransitionTime : CFTimeInterval = 0.0
    
    private var deltas : Sampler = Sampler(period: 12)
    
    private var wvc : BrowserViewController!

    public var isFranticallyChanging : Bool {
        return false
        // return deltas.sum > 7.0
    }
    
    init(inViewController vc : BrowserViewController) {
        
        wvc = vc
        
        pixel = [0, 0, 0, 0]
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )
        
        super.init()
    }
    
    func startUpdates() {
        if colorUpdateTimer == nil {
            colorUpdateTimer = Timer.scheduledTimer(
                timeInterval: MIN_TIME_BETWEEN_UPDATES,
                target: self,
                selector: #selector(self.updateColors),
                userInfo: nil,
                repeats: true
            )
            colorUpdateTimer?.tolerance = 0.3
            RunLoop.main.add(colorUpdateTimer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    func stopUpdates() {
        colorUpdateTimer?.invalidate()
        colorUpdateTimer = nil
        wvc.statusBar.cancelColorChange()
        wvc.toolbar.cancelColorChange()
    }
    
    @objc func updateColors() {
        
        guard wvc.shouldUpdateColors else { return }
        
        let now = CACurrentMediaTime()
        guard ( now - lastSampledColorsTime > MIN_TIME_BETWEEN_UPDATES )  else { return }
        lastSampledColorsTime = now
        
        let sampleH : CGFloat = 12
        let sampleW : CGFloat = webView.frame.width
        let bottomConfig = WKSnapshotConfiguration()
        bottomConfig.rect = CGRect(
            x: webView.frame.width - sampleW,
            y: wvc.cardView.frame.height - Const.shared.statusHeight - Const.shared.toolbarHeight - sampleH,
            width: sampleW,
            height: sampleH
        )
        webView.takeSnapshot(with: bottomConfig) { image, error in
            image?.getColors(scaleDownSize: bottomConfig.rect.size) { colors in
                self.previousBottom = self.bottom
                self.bottom = colors.background
                
                self.wvc.browserTab?.bottomColorSample = self.bottom // this is a hack
                self.wvc.cardView.backgroundColor = self.bottom // this is a hack
                let _ = self.wvc.toolbar.animateGradient(toColor: self.bottom, duration: DURATION, direction: .fromTop)
            }
        }
        let topConfig = WKSnapshotConfiguration()
        topConfig.rect = CGRect(
            x: 0,
            y: 0,
            width: sampleW,
            height: sampleH
        )
        webView.takeSnapshot(with: topConfig) { image, error in
            image?.getColors(scaleDownSize: topConfig.rect.size) { colors in
                self.previousTop = self.top
                self.top = colors.background
                
                self.wvc.browserTab?.topColorSample = self.top // this is a hack
                let didChange = self.wvc.statusBar.animateGradient(toColor: self.top, duration: DURATION, direction: .fromBottom)
                
                if didChange {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                        self.wvc.setNeedsStatusBarAppearanceUpdate()
                    })
                }
            }
        }
        
        
//        getColorAtTopAsync(completion: { newColor in
//            // TODO: if it looks confusing, maybe just go transparent?
//            self.previousTop = self.top
//            self.top = newColor
//            self.topDelta = 1000 // self.top?.difference(from: self.previousTop)
//            self.updateTopColor()
//
//            self.getColorAtBottomAsync(completion: { newColor in
//                // TODO: if it looks confusing, maybe just go transparent?
//                self.previousBottom = self.bottom
//                self.bottom = newColor
//                self.bottomDelta = 1000 // self.top?.difference(from: self.previousTop)
//                self.updateBottomColor()
//            })
//        })
    }
    
    func updateTopColor() {
        self.wvc.browserTab?.topColorSample = self.top // this is a hack
        animateTopToEndState(.fade)
    }
    
    
    func commitTopChange() {
        self.wvc.statusBar.backgroundColor = self.top
    }
    
    func commitBottomChange() {
        self.wvc.toolbar.backgroundColor = self.bottom
    }
    func animateTopToEndState(_ style : ColorTransitionStyle) {
        let didChange = self.wvc.statusBar.animateGradient(toColor: self.top, duration: 1.0, direction: .fromBottom)
        
        if didChange {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.wvc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func blendColors(_ colors: UIColor...) -> UIColor {
        let average : UIColor = UIColor.average(colors)
        
        // Remove outliers
        let blendable : Array<UIColor> = colors.filter({ $0.difference(from: average) < 0.5 })
        
        if blendable.count > 1 {

            return UIColor.average(blendable)
        }
        else {
            let distribution : Float = colors.map({ $0.difference(from: average) }).reduce(0, +)
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
    
    func getColorAtTopAsync(completion: @escaping (UIColor) -> Void ) {
        let size = self.webView.bounds.size
        
        getColorAsync( x: 5, y: 5, completion: { colorAtTopLeft in
            self.getColorAsync( x: size.width - 5,   y: 5, completion: { colorAtTopRight in
                
                if colorAtTopLeft.difference(from: UIColor.white) < 1 {
                    completion(colorAtTopLeft)
                }
                else if colorAtTopRight.difference(from: UIColor.white) < 1 {
                    completion(colorAtTopRight)
                }
                else {
                    let color = self.blendColors(colorAtTopLeft, colorAtTopRight)
                    completion(color)
                }
            })
        })
    }

    
    func getColorAtBottomAsync(completion: @escaping (UIColor) -> Void) {
        let size = self.webView.bounds.size

        getColorAsync(x: 2, y: size.height - 2, completion: { colorAtBottomLeft in
        
            self.getColorAsync( x: size.width - 2, y: size.height - 2, completion: { colorAtBottomRight in
            
                if colorAtBottomLeft.difference(from: colorAtBottomRight) < 1 {
                    let color = self.blendColors(colorAtBottomLeft, colorAtBottomRight)
                    completion(color)
                }
                else {
                    self.getColorAsync( x: 2, y: size.height - 24, completion: { colorAtBottomLeftUp in
                        self.getColorAsync( x: size.width - 2,   y: size.height - 24, completion: { colorAtBottomRightUp in
                            let color = self.blendColors(
                                colorAtBottomLeftUp,
                                colorAtBottomLeft,
                                colorAtBottomRightUp,
                                colorAtBottomRight
                            )
                            completion(color)
                        })
                    })
                }
            })
        })

    }
    
    // adds a frame before and after sampling
    func getColorAsync(x: CGFloat, y: CGFloat, completion: @escaping (UIColor) -> Void) {
        
        DispatchQueue.main.async {
            let color = self.getColorAt(x: x, y: y)
            DispatchQueue.main.async {
                completion(color)
            }
        }
    }

    
    func getColorAt(x: CGFloat, y: CGFloat) -> UIColor {
        
        context!.translateBy(x: -x, y: -y )
        
        UIGraphicsPushContext(context!);
        webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: false)
        UIGraphicsPopContext();
        
        context!.translateBy(x: x, y: y ) // Reset transform because context reused

        
        let color = UIColor( r: CGFloat(pixel[0])/255.0,
                             g: CGFloat(pixel[1])/255.0,
                             b: CGFloat(pixel[2])/255.0 )
        
        return color
    }

    
}
