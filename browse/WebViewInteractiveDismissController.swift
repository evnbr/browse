//
//  WebViewInteractiveDismissController.swift
//  browse
//
//  Created by Evan Brooks on 6/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

enum WebViewInteractiveDismissDirection {
    case top
    case bottom
    case left
    case right
}

// NOTE: There seems to be a problem when webview.scrollview doesn't exist
// that silently logs in xcode, but doesn't seem to break anything.
// Only shows up on blank pages.

class WebViewInteractiveDismissController : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : WebViewController!
    var home : UIViewController!
    
    var view : UIView!
    var toolbar : UIView!
    var webView : WKWebView!
    var statusBar : UIView!
    var cardView : UIView!
    
    var direction : WebViewInteractiveDismissDirection!
    var velocity : CGFloat = 0
    
    init(for vc : WebViewController) {
        super.init()
        
        self.vc = vc
        view = vc.view
        home = vc.home
        webView = vc.webView
        statusBar = vc.statusBar
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
        dismissPanner.cancelsTouchesInView = true
        view.addGestureRecognizer(dismissPanner)
        
        let edgeDismissPan = UIScreenEdgePanGestureRecognizer()
        edgeDismissPan.delegate = self
        edgeDismissPan.edges = .left
        edgeDismissPan.addTarget(self, action: #selector(edgeGestureChange(gesture:)))
        edgeDismissPan.cancelsTouchesInView = true
        view.addGestureRecognizer(edgeDismissPan)
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let contentH = scrollView.contentSize.height
        let viewH = scrollView.bounds.height

        
        if contentH > viewH && scrollView.contentOffset.y < 0 && !scrollView.isDecelerating {
            scrollView.contentOffset.y = 0
        }
        else if isInteractiveDismiss {
            scrollView.contentOffset.y = max(startScroll.y, 0)
        }
    }
    
//    func cancelScroll() {
//        webView.scrollView.isScrollEnabled = false
//        if webView.scrollView.contentOffset.y < 0 {
//            webView.scrollView.contentOffset.y = 0
//        }
//        webView.scrollView.isScrollEnabled = true
//    }
    
    var isInteractiveDismiss : Bool = false
    var startPoint : CGPoint = .zero
    var startScroll : CGPoint = .zero
    
    let DISMISS_POINT_H : CGFloat = 50
    let DISMISS_POINT_V : CGFloat = 300

    @objc func edgeGestureChange(gesture:UIScreenEdgePanGestureRecognizer) {

        if gesture.state == .began {
            direction = .left
            start()
        }
        else if gesture.state == .changed {
            if isInteractiveDismiss && (direction == .left || direction == .right) {
                let gesturePos = gesture.translation(in: view)

                
                let revealProgress = min(gesturePos.x / 200, 1)
                home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
                
                let scale = PRESENT_TAB_BACK_SCALE + revealProgress * 0.5 * (1 - PRESENT_TAB_BACK_SCALE)
                home.navigationController?.view.transform = CGAffineTransform(scaleX: scale, y: scale)
                
                let adjustedX = elasticLimit(gesturePos.x)
                
                cardView.frame.origin.x = adjustedX
                
                
            }
        }
        else if gesture.state == .ended {
            let gesturePos = gesture.translation(in: view)
            
            if gesturePos.x > DISMISS_POINT_H { commit() }
            else { reset() }
        }
    }
    
    func considerStarting(gesture: UIPanGestureRecognizer) {
        let scrollY = webView.scrollView.contentOffset.y
        let contentH = webView.scrollView.contentSize.height
        let viewH = webView.scrollView.bounds.height
        
        let maxScroll = contentH - viewH

        
        let gesturePos = gesture.translation(in: view)

        if contentH > viewH {
            if scrollY == 0 && gesturePos.y > 0 {
                direction = .top
                startPoint = gesturePos
                start()
            }
            else if scrollY > maxScroll {
                direction = .bottom
                startPoint = gesturePos
                start()
            }
        }
        else {
            if scrollY < 0 && gesturePos.y > 0 {
                direction = .top
                startPoint = gesturePos
                start()
            }
        }
        
    }
    
    
//    var statusBarAnimator : UIViewPropertyAnimator!
    
    var shouldRestoreKeyboard : Bool = false
    
    func start() {
        isInteractiveDismiss = true
        startScroll = webView.scrollView.contentOffset
        
        
        if vc.isDisplayingSearch {
            vc.hideSearch()
        }
        
    }
    
    func end() {
        isInteractiveDismiss = false
    }
    
    func commit() {
        end()
        vc.dismissSelf()
    }
    
    func reset(atVelocity vel : CGFloat = 0.0) {
        end()
        
        UIView.animate(withDuration: 0.6, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
            self.vc.resetSizes(withKeyboard: self.shouldRestoreKeyboard)
            self.vc.setNeedsStatusBarAppearanceUpdate()
            self.vc.home.navigationController?.view.alpha = 0
        }, completion: nil)
        
        if shouldRestoreKeyboard {  // HACK, COPY PASTED EVERYWHERE
            shouldRestoreKeyboard = false
            vc.displaySearch()
        }
        
    }
    
    func elasticLimit(_ val : CGFloat) -> CGFloat {
        let resist = 1 - log10(1 + abs(val) / 150) // 1 ... 0.5
        return val * resist
    }
    
    func update(gesture:UIPanGestureRecognizer) {
        
        let gesturePos = gesture.translation(in: view)
        var adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
            
            
            end()
            vc.resetSizes(withKeyboard: shouldRestoreKeyboard)
            if shouldRestoreKeyboard {  // HACK, COPY PASTED EVERYWHERE
                shouldRestoreKeyboard = false
                vc.displaySearch()
            }
            return
        }
        
        adjustedY = elasticLimit(adjustedY)
        
        
        let statusOffset : CGFloat = 0 // min(STATUS_H, (abs(adjustedY) / 300) * STATUS_H)
        webView.frame.origin.y = STATUS_H - statusOffset
        statusBar.frame.origin.y = 0 - statusOffset
        
        cardView.frame.origin.y = adjustedY
        
        if adjustedY > 0 {
            cardView.frame.size.height = view.frame.height - TOOLBAR_H - (abs(adjustedY))
        }
        
        
        let revealProgress = abs(adjustedY) / 200
        home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
        let scale = PRESENT_TAB_BACK_SCALE + revealProgress * 0.5 * (1 - PRESENT_TAB_BACK_SCALE)
        home.navigationController?.view.transform = CGAffineTransform(scaleX: scale, y: scale)

        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
//        statusBarAnimator.fractionComplete = abs(adjustedY) / 50
    }
    
    
    @objc func panGestureChange(gesture: UIPanGestureRecognizer) {

        if gesture.state == .began {
            considerStarting(gesture: gesture)
        }
            
        else if gesture.state == .changed {
            
            if isInteractiveDismiss && !(direction == .left) {
                update(gesture: gesture)
            }
            else if !isInteractiveDismiss {
                considerStarting(gesture: gesture)
            }
        }
            
        else if gesture.state == .ended {
            if isInteractiveDismiss && !(direction == .left) {
                let gesturePos = gesture.translation(in: view)
                let adjustedY : CGFloat = gesturePos.y - startPoint.y

                let vel = gesture.velocity(in: vc.view)
                
                
                if (direction == .top && (vel.y > 600 || adjustedY > DISMISS_POINT_V)) {
                    commit()
                }
                else if (direction == .bottom && (vel.y < -600 || adjustedY < -DISMISS_POINT_V)) {
                    commit()
                }
                else {
                    reset(atVelocity: vel.y)
                }
            }
            
        }
    }
    
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // only recognize verticals
//    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        if gestureRecognizer is UIScreenEdgePanGestureRecognizer { return true }
//        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
//            let translation = panGestureRecognizer.translation(in: view!)
//            if fabs(translation.x) < fabs(translation.y) {
//                print("Beding Interactive Dismiss")
//                return true
//            }
//            return false
//        }
//        return false
//    }
    
    var isInteractiveDismissToolbar : Bool = false
    var interactiveDismissToolbarStartPoint : CGPoint = .zero

}
