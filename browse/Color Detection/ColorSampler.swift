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

let DURATION = 0.9
let MIN_TIME_BETWEEN_UPDATES = 0.15


protocol ColorSamplerDelegate {
    
}

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
        
    private var wvc : BrowserViewController!
    
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
        
        let sampleH : CGFloat = 5
        let sampleW : CGFloat = webView.bounds.width
        let bottomConfig = WKSnapshotConfiguration()
        bottomConfig.rect = CGRect(
            x: 0,
            y: wvc.cardView.bounds.height - (-wvc.toolbarBottomConstraint.constant) - Const.shared.statusHeight - wvc.toolbarHeightConstraint.constant - sampleH,
            width: sampleW,
            height: sampleH
        )
        webView.takeSnapshot(with: bottomConfig) { image, error in
            image?.getColors(scaleDownSize: bottomConfig.rect.size) { colors in
                self.previousBottom = self.bottom
                self.bottom = colors.background
                self.wvc.browserTab?.bottomColorSample = self.bottom // this is a hack

                if self.wvc.shouldUpdateColors {
                    self.wvc.cardView.backgroundColor = self.bottom // this is a hack
                    let _ = self.wvc.toolbar.animateGradient(toColor: self.bottom, duration: DURATION, direction: .fromTop)
                }
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

                if self.wvc.shouldUpdateColors {
                    let didChange = self.wvc.statusBar.animateGradient(toColor: self.top, duration: DURATION, direction: .fromBottom)
                    
                    if didChange {
                        UIView.animate(withDuration: 0.2, delay: 0.1, options: .curveEaseInOut, animations: {
                            self.wvc.setNeedsStatusBarAppearanceUpdate()
                        })
                    }
                }
            }
        }
    }
    
    func updateTopColor() {
        self.wvc.browserTab?.topColorSample = self.top // this is a hack
        animateTopToEndState(.fade)
    }
    
    func animateTopToEndState(_ style : ColorTransitionStyle) {
        let didChange = self.wvc.statusBar.animateGradient(toColor: self.top, duration: 1.0, direction: .fromBottom)
        
        if didChange {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.wvc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
}
