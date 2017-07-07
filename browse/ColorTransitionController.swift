//
//  ColorTransitionController.swift
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

let DURATION = 0.3

class ColorTransitionController : NSObject, UIGestureRecognizerDelegate {
    
    let TOOLBAR_H : CGFloat = 36.0
    let STATUS_H : CGFloat = 22.0
    let MIN_TIME_BETWEEN_UPDATES = 0.2
    
    private var colorUpdateTimer : Timer!

    private var webView: WKWebView!
    
    private var isTopAnimating : Bool = false
    private var isBottomAnimating : Bool = false
    private var isPanning : Bool = false
    private var wasScrollingDown : Bool = true
    
    private var isBottomTransitionInteractive = false
    private var isTopTransitionInteractive = false

    private var context: CGContext!
    private var pixel: [CUnsignedChar]
    
    public var top: UIColor = UIColor.white
    public var bottom: UIColor = UIColor.white
    
    public var previousTop: UIColor = UIColor.white
    public var previousBottom: UIColor = UIColor.white
    
    public var topDelta: Float = 0.0
    public var bottomDelta: Float = 0.0
    
    var lastSampledColorsTime : CFTimeInterval = 0.0
    var lastTopTransitionTime : CFTimeInterval = 0.0
    var lastBottomTransitionTime : CFTimeInterval = 0.0
    
    private var deltas : Sampler = Sampler(period: 12)
    
    private var wvc : WebViewController!

    public var isFranticallyChanging : Bool {
        return false
        // return deltas.sum > 7.0
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
        
        startUpdates()
        
//        let touchRecognizer = UIPanGestureRecognizer()
//        touchRecognizer.delegate = self
//        touchRecognizer.addTarget(self, action: #selector(self.onWebviewPan))
//        webView.scrollView.addGestureRecognizer(touchRecognizer)

        
//        let snapshotTimer = Timer.scheduledTimer(
//            timeInterval: (1/30.0),
//            target: self,
//            selector: #selector(self.updateSnapshots),
//            userInfo: nil,
//            repeats: true
//        )
//        RunLoop.main.add(snapshotTimer, forMode: RunLoopMode.commonModes)

//        let snapshotDisplayLink = CADisplayLink(target: self, selector: #selector(self.updateSnapshots))
//        snapshotDisplayLink.add(to: .main, forMode: .commonModes)
        
    }
    
    func startUpdates() {
        if colorUpdateTimer == nil {
            colorUpdateTimer = Timer.scheduledTimer(
                timeInterval: MIN_TIME_BETWEEN_UPDATES + 0.1,
                target: self,
                selector: #selector(self.updateColors),
                userInfo: nil,
                repeats: true
            )
            colorUpdateTimer.tolerance = 0.2
            RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)
        }
    }
    
    func stopUpdates() {
        colorUpdateTimer.invalidate()
        colorUpdateTimer = nil
    }
    
    func updateSnapshots() {
        guard UIApplication.shared.applicationState == .active else { return }
        guard (wvc.isViewLoaded && (wvc.view.window != nil)) else { return }
        
        updateTopSnapshot()
        updateBottomSnapshot()
        updateBottomBlendSnapshot()
    }
    
    var topSnapshot : UIView!
    func updateTopSnapshot() {
        
        let SAMPLE_H : CGFloat = 4.0
        
        topSnapshot?.removeFromSuperview()
        topSnapshot = webView.resizableSnapshotView(
            from: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: SAMPLE_H),
            afterScreenUpdates: false,
            withCapInsets: .zero
        )
//        topSnapshot.frame.origin.y = 7
        topSnapshot.frame.size.height = STATUS_H
//        topSnapshot.transform = CGAffineTransform(scaleX: 1, y: TOOLBAR_H / SAMPLE_H)
        
        wvc.statusBar.addSubview(topSnapshot)
//        wvc.statusBar.bringSubview(toFront: wvc.statusBar.blurView)
    }
    
    var bottomSnapshot : UIView!
    func updateBottomSnapshot() {
        let SAMPLE_H : CGFloat = 4.0
        
        bottomSnapshot?.removeFromSuperview()
        bottomSnapshot = webView.resizableSnapshotView(
            from: CGRect(
                x: 0,
                y: wvc.webView.frame.height - 4,
                width: UIScreen.main.bounds.width,
                height: SAMPLE_H),
            afterScreenUpdates: false,
            withCapInsets: .zero
        )
        bottomSnapshot.frame.origin.y = 18
//        bottomSnapshot.frame.size.width = UIScreen.main.bounds.width
        
        bottomSnapshot.transform = CGAffineTransform(scaleX: 1, y: 10)
        
        wvc.toolbar.addSubview(bottomSnapshot)
        wvc.toolbar.sendSubview(toBack: bottomSnapshot)
//        wvc.toolbar.sendSubview(toBack: wvc.toolbar.inner)
//        wvc.toolbar.sendSubview(toBack: wvc.toolbar.back)
    }
    
    var bottomBlendSnapshot : UIView!
    func updateBottomBlendSnapshot() {
        let SAMPLE_H : CGFloat = 4.0
        
        bottomBlendSnapshot?.removeFromSuperview()
        bottomBlendSnapshot = webView.resizableSnapshotView(
            from: CGRect(
                x: 0,
                y: wvc.webView.frame.height - 8,
                width: UIScreen.main.bounds.width,
                height: SAMPLE_H),
            afterScreenUpdates: false,
            withCapInsets: .zero
        )
        bottomBlendSnapshot.frame.origin.y = wvc.webView.frame.height + STATUS_H - 8
        
        bottomBlendSnapshot.transform = CGAffineTransform(scaleX: 1, y: 2)
        
        wvc.view.addSubview(bottomBlendSnapshot)
    }

    
    
    @objc func updateColors() {
        
        guard wvc.shouldUpdateColors else { return }
        
        let now = CACurrentMediaTime()
        guard ( now - lastSampledColorsTime > MIN_TIME_BETWEEN_UPDATES )  else { return }
        lastSampledColorsTime = now

        
        if !isTopAnimating && !isTopTransitionInteractive {
            getColorAtTopAsync(completion: { newColor in
                // TODO: if it looks confusing, maybe just go transparent?
                self.previousTop = self.top
                self.top = newColor
                self.topDelta = self.top.difference(from: self.previousTop)
                self.deltas.addSample(value: self.topDelta > 0.3 ? 1 : 0)
                self.updateTopColor()
                // self.wvc.updateStatusbarLayering()
            })
        }
        
//        if !isBottomAnimating {
//            getColorAtBottomAsync(completion: { newColor in
//                if !self.isBottomTransitionInteractive {
//                    self.previousBottom = self.bottom
//                    self.bottom = newColor
//                    self.bottomDelta = self.bottom.difference(from: self.previousBottom)
//                    self.deltas.addSample(value: self.bottomDelta > 0.3 ? 1 : 0)
//                    self.updateBottomColor()
//                }
//            })
//        }

    }
    
    func updateTopColor() {
        if !isTopTransitionInteractive && self.topDelta > 0 {
            wvc.statusBar.inner.transform = CGAffineTransform(translationX: 0, y: STATUS_H)
            wvc.statusBar.inner.isHidden = false
            wvc.statusBar.inner.backgroundColor = self.top
            self.wvc.topLabel?.backgroundColor = self.top
            self.wvc.topLabel?.textColor = self.top.isLight ? .white : .darkText

        }
        
        if isPanning && !isTopTransitionInteractive && self.topDelta > 0.6 {
            topInteractiveTransitionStart()
            return
        }
        
        if self.isFranticallyChanging {
            wvc.statusBar.back.backgroundColor = .black
            wvc.setNeedsStatusBarAppearanceUpdate()
        }
        else {
            if !isTopAnimating && self.topDelta > 0 {
                animateTopToEndState(.fade)
            }
        }

    }
    
    
    func updateBottomColor() {

//        if !isBottomTransitionInteractive && self.bottomDelta > 0 {
//            wvc.toolbar.inner.transform = CGAffineTransform(translationX: 0, y: -TOOLBAR_H)
//            wvc.toolbar.inner.backgroundColor = self.bottom
//            wvc.toolbar.inner.isHidden = false
//        }
//
//        if isPanning && !isBottomTransitionInteractive && self.bottomDelta > 0.6 {
//            bottomInteractiveTransitionStart()
//            return
//        }
//
//        if self.isFranticallyChanging {
//            wvc.toolbar.back.backgroundColor = .black
//            wvc.toolbar.tintColor = .white
//        }
//        else {
//            if !isBottomAnimating && self.bottomDelta > 0 {
//                animateBottomEndState(.fade)
//            }
//        }
        
        
    }
    
    func commitTopChange() {
//        print("commit top")
        self.wvc.statusBar.back.backgroundColor = self.top
        self.wvc.statusBar.inner.isHidden = true
//        self.webView.scrollView.backgroundColor = self.top
    }

    func commitBottomChange() {
//        self.wvc.toolbar.back.backgroundColor = self.bottom
//        self.wvc.toolbar.inner.isHidden = true
        
        self.wvc.toolbar.progressView.progressTintColor = self.bottom.isLight
            ? UIColor.lightOverlay
            : UIColor.darkOverlay
        
        let newTint : UIColor = self.bottom.isLight ? .white : .darkText
        if self.wvc.toolbar.tintColor != newTint {
            UIView.animate(withDuration: 0.2) {
                self.wvc.toolbar.tintColor = newTint
            }
        }

    }
    func animateTopToEndState(_ style : ColorTransitionStyle) {
//        let shouldThrottleTop = true//CACurrentMediaTime() - lastTopTransitionTime    < 1.0
        
//        print("animate top")
        isTopAnimating = true

        UIView.animate(withDuration: DURATION, delay: 0, options: .curveEaseInOut, animations: {
            if self.topDelta > 0 {
                if style == .translate && self.topDelta > 0.6 {
                    self.wvc.statusBar.inner.transform  = .identity
                    self.lastTopTransitionTime          = CACurrentMediaTime()
                    self.wvc.statusBar.back.backgroundColor = self.previousTop.withBrightness(0.2)
                } else {
                    self.wvc.statusBar.back.backgroundColor = self.top
                }
                self.wvc.setNeedsStatusBarAppearanceUpdate()
            }
        }, completion: { completed in
            if (completed) {
                self.commitTopChange()
            }
            else {
                print("Top animation never completed")
                self.commitTopChange()
            }
            self.isTopAnimating = false
            
        })

    }

    func animateBottomEndState(_ style : ColorTransitionStyle) {
//        let shouldThrottleBottom = true//CACurrentMediaTime() - lastBottomTransitionTime < 1.0
        
        isBottomAnimating = true
        
        UIView.animate(withDuration: DURATION, delay: 0, options: .curveEaseInOut, animations: {
            if self.bottomDelta > 0 {
                if style == .translate && self.bottomDelta > 0.6 {
//                    self.wvc.toolbar.inner.transform = .identity
                    self.lastBottomTransitionTime   = CACurrentMediaTime()
//                    self.wvc.toolbar.back.backgroundColor   = UIColor.average(self.previousBottom, self.bottom )
                } else {
//                    self.wvc.toolbar.back.backgroundColor   = self.bottom
                }
                self.wvc.toolbar.tintColor = self.bottom.isLight ? .white : .darkText
            }
        }, completion: { completed in
            if (completed) {
                self.commitBottomChange()
            }
            else {
                print("Bottom animation never completed")
            }
            self.isBottomAnimating = false
            
        })
    }
    
    var gestureCurrentY : CGFloat = 0.0

    var bottomTransitionStartY : CGFloat = 0.0
    var bottomYRange : ClosedRange<CGFloat> = (0.0 ... 0.0)
    var bottomTransitionStartTint  : UIColor = UIColor.black
    var bottomTransitionEndTint : UIColor = UIColor.black
    func bottomInteractiveTransitionStart() {
        isBottomTransitionInteractive = true
//        self.wvc.toolbar.inner.isHidden = false
        
        let amt = TOOLBAR_H * 1.0

        bottomTransitionStartY = gestureCurrentY + (self.wasScrollingDown ? -amt : amt)
        bottomYRange = self.wasScrollingDown
            ? (  0.0 ... amt)
            : (-amt ...  0.0)
        
        bottomTransitionStartTint = self.previousBottom.isLight ? .white : .darkText
        bottomTransitionEndTint   = self.bottom.isLight         ? .white : .darkText
    }
    func bottomInteractiveTransitionChange() {
        let y = gestureCurrentY - bottomTransitionStartY
        let clampedY = -abs( bottomYRange.clamp(y) ) * ( 1 / 1.0 )
        // let clampedY = ( bottomYRange.clamp(y) ) * ( 1 / 1.0 )
        
        if abs(clampedY) > TOOLBAR_H {
            // todo: this transition is broken. we should instead prevent reversing, which doesnt make sense anyways, and just continuing at same speed while the finger is down
            bottomInteractiveTransitionEnd(animated: true)
        }
        
        let progress = 1 - abs(clampedY) / TOOLBAR_H
        
//        wvc.toolbar.inner.transform = CGAffineTransform(translationX: 0, y: clampedY)
//        wvc.toolbar.back.backgroundColor = self.previousBottom.withBrightness( 1 - (progress * 0.8))
        
        
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
    func bottomInteractiveTransitionEnd(animated : Bool) {
        isBottomTransitionInteractive = false
        if animated {
            animateBottomEndState(.translate)
        }
        else {
            commitBottomChange()
        }
    }

    var topTransitionStartY : CGFloat = 0.0
    var topYRange : ClosedRange<CGFloat> = (0.0 ... 0.0)
    func topInteractiveTransitionStart() {
        
//        print("top interactive start")

        isTopTransitionInteractive = true
        self.wvc.statusBar.inner.isHidden = false
        
        let amt = STATUS_H * 1.0
        
        topTransitionStartY = gestureCurrentY + (self.wasScrollingDown ? -amt : amt)
        topYRange = self.wasScrollingDown
            ? (  0.0 ... amt)
            : (-amt ...  0.0)
    }

    
    func topInteractiveTransitionChange() {
        let y = gestureCurrentY - topTransitionStartY
        let clampedY = abs( topYRange.clamp(y) ) * ( 1 / 1.0 )
        // let clampedY = ( topYRange.clamp(y) ) * ( 1 / 1.0 )
        
        
        if abs(clampedY) > STATUS_H {
            // todo: this transition is broken. we should instead prevent reversing, which doesnt make sense anyways, and just continuing at same speed while the finger is down
//            bottomInteractiveTransitionEnd(animated: true)
        }
        
        let progress = 1 - abs(clampedY) / STATUS_H
//        print("top interactive change y:\(clampedY) prog:\(progress)")

        wvc.statusBar.back.backgroundColor = self.previousTop.withBrightness( 1 - (progress * 0.8))
        wvc.statusBar.inner.transform = CGAffineTransform(translationX: 0, y: clampedY)

        // TODO only trigger at 50%, only if there is a change, make cancelable
        if progress > 0.2 {
            UIView.animate(withDuration: 0.3) {
                self.wvc.setNeedsStatusBarAppearanceUpdate()
            }
        }

        if clampedY == 0.0 {
            topInteractiveTransitionEnd(animated: false)
        }
    }
    
    func topInteractiveTransitionEnd(animated : Bool) {
//        print("top interactive end")

        isTopTransitionInteractive = false
        if animated {
            animateTopToEndState(.translate)
        }
        else {
            commitTopChange()
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
            if isTopTransitionInteractive {
                topInteractiveTransitionChange()
            }
//            if !isBottomTransitionInteractive || !isTopTransitionInteractive {
//                updateColors() // this will be throttled
//            }
        }
            
        else if gesture.state == .ended {
            self.isPanning = false
            
            if isBottomTransitionInteractive {
                bottomInteractiveTransitionEnd(animated: true)
            }
            if isTopTransitionInteractive {
                topInteractiveTransitionEnd(animated: true)
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
    
    func getColorAtTopAsync(completion: @escaping (UIColor) -> Void ) {
        let size = self.webView.bounds.size
        
        getColorAsync( x: 5, y: 1, completion: { colorAtTopLeft in
            self.getColorAsync( x: size.width - 5,   y: 1, completion: { colorAtTopRight in
                
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

        
        let color = UIColor( colorLiteralRed: Float(pixel[0])/255.0,
                             green:           Float(pixel[1])/255.0,
                             blue:            Float(pixel[2])/255.0,
                             alpha:           Float(pixel[3])/255.0 )
        
        return color
    }

    
}
