//
//  WebViewColorFetcher.swift
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


class WebViewColorFetcher : NSObject, UIGestureRecognizerDelegate {
    
    private var webView: WKWebView!
    
    private var isAnimating : Bool = false
    private var isPanning : Bool = false
    private var wasScrollingDown : Bool = true
    
    private var isBottomTransitionInteractive = false

    private var context: CGContext!
    private var pixel: [CUnsignedChar]
    
    public var top: UIColor = UIColor.white
    public var bottom: UIColor = UIColor.white
    
    public var previousTop: UIColor = UIColor.white
    public var previousBottom: UIColor = UIColor.white
    
    public var topDelta: Float = 0.0
    public var bottomDelta: Float = 0.0
    
    var lastUpdatedColors : CFTimeInterval = 0.0
    var lastTopTransitionTime : CFTimeInterval = 0.0
    var lastBottomTransitionTime : CFTimeInterval = 0.0
    
    private var deltas : Sampler = Sampler(period: 12)
    
    private var wvc : WebViewController!

    public var isFranticallyChanging : Bool {
        get {
            return deltas.sum > 7.0
        }
    }
    
    init(from sourceWebView : WKWebView, inViewController vc : WebViewController) {
        
        webView = sourceWebView
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

        // Detect panning to prevent firing when faux-scrolling, like in maps and carousels
        let touchRecognizer = UIPanGestureRecognizer()
        touchRecognizer.delegate = self
        touchRecognizer.addTarget(self, action: #selector(self.onWebviewPan))
        webView.scrollView.addGestureRecognizer(touchRecognizer)

        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.6,
            target: self,
            selector: #selector(self.updateColors),
            userInfo: nil,
            repeats: true
        )
        colorUpdateTimer.tolerance = 0.2
        
        // Note: rather than run on the main loop, which drops frames during inertial scroll, we add additional throttled calls during panning. (imo dropped frames when the finger is down is slightly more forgiving than during animation)
        // RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)

    }
    
    func updateColors() {
        
//        guard !self.isPanning else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        guard !isAnimating else { return }
        guard !isBottomTransitionInteractive else { return }

        let now = CACurrentMediaTime()
        guard ( now - lastUpdatedColors > 0.5 )  else { return }
        lastUpdatedColors = now

        
        previousTop = top
        previousBottom = bottom
        
        top = getColorAtTop()
//        bottom = UIColor.black
        bottom = getColorAtBottom()
        
        topDelta    = top.difference(from: previousTop)
        bottomDelta = bottom.difference(from: previousBottom)
        
        deltas.addSample(value:    topDelta > 0.3 ? 1 : 0)
        deltas.addSample(value: bottomDelta > 0.3 ? 1 : 0)

        updateInterfaceColor()
    }
    
    
    func updateInterfaceColor() {

        
        if self.topDelta > 0 {
            wvc.statusBar.inner.transform = CGAffineTransform(translationX: 0, y: 20)
            wvc.statusBar.inner.isHidden = false

//            wvc.statusBar.inner.transform = CGAffineTransform(translationX: 0, y: (self.wasScrollingDown ? 20 : -20))
            wvc.statusBar.inner.backgroundColor = self.top
        }
        if self.bottomDelta > 0 {
            wvc.toolbarInner.transform = CGAffineTransform(translationX: 0, y: -48)
//            wvc.toolbarInner.transform = CGAffineTransform(translationX: 0, y: (self.wasScrollingDown ? 48 : -48))
            wvc.toolbarInner.backgroundColor = self.bottom
            wvc.toolbarInner.isHidden = false
        }
        
        if isPanning && !isBottomTransitionInteractive && self.bottomDelta > 0.6 {
            bottomInteractiveTransitionStart()
            return
        }

        if self.isFranticallyChanging {
            
            wvc.statusBar.back.backgroundColor = .black
            wvc.toolbar.barTintColor = .black
            wvc.toolbar.tintColor = .white
            
            wvc.toolbar.layoutIfNeeded()
            wvc.setNeedsStatusBarAppearanceUpdate()
        }
        else {
            animateToEndState()
        }
        
    }
    
    func commitColorChange() {
        self.wvc.toolbar.barTintColor = self.bottom
        self.wvc.toolbarInner.isHidden = true
        
        self.wvc.statusBar.back.backgroundColor = self.top
        self.wvc.statusBar.inner.isHidden = true
        self.wvc.toolbar.layoutIfNeeded()

        let newTint : UIColor = self.bottom.isLight ? .white : .darkText
        if self.wvc.toolbar.tintColor != newTint {
            UIView.animate(withDuration: 0.2) {
                self.wvc.toolbar.tintColor = newTint
                self.wvc.toolbar.layoutIfNeeded()
            }
        }

    }
    
    func animateToEndState() {
        let shouldThrottleTop    = CACurrentMediaTime() - lastTopTransitionTime    < 1.0
        let shouldThrottleBottom = CACurrentMediaTime() - lastBottomTransitionTime < 1.0
        
        wvc.progressView.progressTintColor = self.bottom.isLight
            ? UIColor.white.withAlphaComponent(0.2)
            : UIColor.black.withAlphaComponent(0.08)
        
        isAnimating = true
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            if self.topDelta > 0 {
                if !shouldThrottleTop && self.topDelta > 0.6 {
                    self.wvc.statusBar.inner.transform      = .identity
                    self.lastTopTransitionTime          = CACurrentMediaTime()
                    self.wvc.statusBar.back.backgroundColor = self.previousTop.withBrightness(0.2)
                } else {
                    self.wvc.statusBar.back.backgroundColor = self.top
                }
                self.wvc.setNeedsStatusBarAppearanceUpdate()
            }
            if self.bottomDelta > 0 {
                if !shouldThrottleBottom && self.bottomDelta > 0.6 {
                    self.wvc.toolbarInner.transform    = .identity
                    self.lastBottomTransitionTime  = CACurrentMediaTime()
                    //                        self.toolbar.barTintColor      = self.webViewColor.previousBottom.withBrightness(0.2)
                    self.wvc.toolbar.barTintColor      = UIColor.average(self.previousBottom, self.bottom )
                } else {
                    self.wvc.toolbar.barTintColor      = self.bottom
                }
                self.wvc.toolbar.tintColor = self.bottom.isLight ? .white : .darkText
                self.wvc.toolbar.layoutIfNeeded()
            }
        }, completion: { completed in
            if (completed) {
                self.commitColorChange()
            }
            else {
                print("Animation never completed")
            }
            self.isAnimating = false
            
        })
    }
    
    var bottomTransitionStartY : CGFloat = 0.0
    var gestureCurrentY : CGFloat = 0.0
    var bottomYRange : ClosedRange<CGFloat> = (-48.0 ... 48.0)
    var bottomTransitionStartTint  : UIColor = UIColor.black
    var bottomTransitionEndTint : UIColor = UIColor.black
    let TOOLBAR_H : CGFloat = 48.0
    
    func bottomInteractiveTransitionStart() {
        isBottomTransitionInteractive = true
        self.wvc.toolbarInner.isHidden = false
        
        let amt = TOOLBAR_H * 2.0

        bottomTransitionStartY = gestureCurrentY + (self.wasScrollingDown ? -amt : amt)
        bottomYRange = self.wasScrollingDown
            ? (  0.0 ... amt)
            : (-amt ...  0.0)
        
        bottomTransitionStartTint = self.previousBottom.isLight ? .white : .darkText
        bottomTransitionEndTint   = self.bottom.isLight         ? .white : .darkText
    }
    
    func bottomInteractiveTransitionChange() {
        let y = gestureCurrentY - bottomTransitionStartY
        let clampedY = -abs( bottomYRange.clamp(y) ) * 0.5
                
        if abs(clampedY) > 48.0 {
            // todo: this transition is broken
            bottomInteractiveTransitionEnd(animated: false)
        }
        
        wvc.toolbarInner.transform = CGAffineTransform(translationX: 0, y: clampedY)
        
        let progress = 1 - abs(clampedY) / 48

        let newTint : UIColor = progress > 0.5
            ? self.bottomTransitionEndTint
            : self.bottomTransitionStartTint
        
        if !newTint.isEqual(self.wvc.toolbar.tintColor) {
            UIView.animate(withDuration: 0.2) {
                self.wvc.toolbar.tintColor = newTint
            }
        }

        if clampedY == 0.0 {
            bottomInteractiveTransitionEnd(animated: false)
        }
    }
    
    func bottomInteractiveTransitionCancel() {
        self.wvc.toolbarInner.isHidden = true
        isBottomTransitionInteractive = false
    }
    
    func bottomInteractiveTransitionEnd(animated : Bool) {
        isBottomTransitionInteractive = false
        if animated {
            animateToEndState()
        }
        else {
            commitColorChange()
        }
    }


    
    func onWebviewPan(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            self.isPanning = true
        }
            
        else if gesture.state == .changed {
            let velY = gesture.velocity(in: webView).y
            self.wasScrollingDown = velY < 0
            
            gestureCurrentY = gesture.translation(in: webView).y
            
            if isBottomTransitionInteractive {
                bottomInteractiveTransitionChange()
            }
            else {
                updateColors() // this will be throttled
            }
        }
            
        else if gesture.state == .ended {
            self.isPanning = false
            
            if isBottomTransitionInteractive {
                bottomInteractiveTransitionEnd(animated: true)
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
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
