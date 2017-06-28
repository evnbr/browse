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

class WebViewInteractiveDismissController : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : WebViewController!
    var home : UIViewController!
    
    var view : UIView!
    var toolbar : UIView!
    var webView : UIView!
    var statusBar : UIView!
    var scrollView : UIScrollView!
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
        scrollView = vc.webView.scrollView
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
        dismissPanner.cancelsTouchesInView = true
        view.addGestureRecognizer(dismissPanner)
        
//        let toolbarDismissPanner = UIPanGestureRecognizer()
//        toolbarDismissPanner.delegate = self
//        toolbarDismissPanner.addTarget(self, action: #selector(toolbarDismissPan(gesture:)))
//        toolbarDismissPanner.cancelsTouchesInView = true
//        toolbar.addGestureRecognizer(toolbarDismissPanner)
        
        let edgeDismissPan = UIScreenEdgePanGestureRecognizer()
        edgeDismissPan.delegate = self
        edgeDismissPan.edges = .left
        edgeDismissPan.addTarget(self, action: #selector(edgeGestureChange(gesture:)))
        edgeDismissPan.cancelsTouchesInView = true
        view.addGestureRecognizer(edgeDismissPan)

    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 && !scrollView.isDecelerating {
            scrollView.contentOffset.y = 0
        }
        else if isInteractiveDismiss {
            scrollView.contentOffset.y = startScroll.y
        }
    }
    


    func cancelScroll() {
        scrollView.isScrollEnabled = false
        if scrollView.contentOffset.y < 0 {
            scrollView.contentOffset.y = 0
        }
        scrollView.isScrollEnabled = true
    }
    
    var isInteractiveDismiss : Bool = false
    var startPoint : CGPoint = .zero
    var startScroll : CGPoint = .zero
    
    let DISMISS_POINT_H : CGFloat = 100
    let DISMISS_POINT_V : CGFloat = 100

    func edgeGestureChange(gesture:UIScreenEdgePanGestureRecognizer) {

        if gesture.state == .began {
            direction = .left
            start()
        }
        else if gesture.state == .changed {
            if isInteractiveDismiss && direction == .left {
                let gesturePos = gesture.translation(in: view)

                cardView.frame.origin.x = gesturePos.x
                
                let revealProgress = min(gesturePos.x / 200, 1)
                home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
                toolbar.alpha = 1 - (abs(gesturePos.x) / 200)

                if gesturePos.x > DISMISS_POINT_H {
                    let amountOver : CGFloat = gesturePos.x - DISMISS_POINT_H
                    
                    cardView.frame.origin.x = DISMISS_POINT_H + amountOver * 0.5
                    
//                    cardView.frame.origin.y = amountOver * 0.1
//                    cardView.frame.size.height = max(view.frame.height - TOOLBAR_H - (amountOver * 1.2), THUMB_H * 1.1)
                }

                if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.vc.setNeedsStatusBarAppearanceUpdate()
                    })
                }

            }
        }
        else if gesture.state == .ended {
            let gesturePos = gesture.translation(in: view)
            
            if gesturePos.x > DISMISS_POINT_H { commit() }
            else { reset() }
        }
    }
    
    func considerStarting(gesture: UIPanGestureRecognizer) {
        let scrollY = scrollView.contentOffset.y
        let endY = scrollView.contentSize.height - scrollView.bounds.height
        
        let gesturePos = gesture.translation(in: view)

        
        if scrollY == 0 && gesturePos.y > 0 {
            direction = .top
            startPoint = gesturePos
            start()

        }
        else if scrollY > endY {
            direction = .bottom
            startPoint = gesturePos
            start()
        }
    }
    
    
//    var statusBarAnimator : UIViewPropertyAnimator!

    func start() {
        isInteractiveDismiss = true
        startScroll = scrollView.contentOffset
        
//        statusBarAnimator = UIViewPropertyAnimator(duration: 2.0, curve: .easeInOut, animations: { 
//            self.vc.setNeedsStatusBarAppearanceUpdate()
//        })
        
    }
    
    func end() {
        isInteractiveDismiss = false
    }
    
    func commit() {
        end()
        vc.dismissSelf()
    }
    
    func reset() {
        end()
        
        UIView.animate(withDuration: 0.6, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
            self.vc.resetSizes()
            self.vc.setNeedsStatusBarAppearanceUpdate()
            self.vc.home.navigationController?.view.alpha = 0
        }, completion: nil)
    }
    
    func update(gesture:UIPanGestureRecognizer) {
        
        let gesturePos = gesture.translation(in: view)
        let adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
//            adjustedY = adjustedY * 0.1
            end()
            vc.resetSizes()
            return
        }
        
        let statusOffset : CGFloat = 0 // min(STATUS_H, (abs(adjustedY) / 300) * STATUS_H)
        webView.frame.origin.y = STATUS_H - statusOffset
        statusBar.frame.origin.y = 0 - statusOffset
        
        cardView.frame.origin.y = direction == .top
            ? adjustedY + statusOffset
            : adjustedY * -0.2
        
//        cardView.frame.size.height = max(view.frame.height - TOOLBAR_H - (abs(adjustedY) * 1.2), THUMB_H * 1.1)
        cardView.frame.size.height = max(view.frame.height - TOOLBAR_H - (abs(adjustedY) * 0.9), THUMB_H * 1.1)
        
        if direction == .bottom && adjustedY < 0 {
            scrollView.contentOffset.y = startScroll.y - adjustedY
        }
        
        toolbar.alpha = 1 - (abs(adjustedY) / 100)
        
        let revealProgress = abs(adjustedY) / 200
        home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
//        statusBarAnimator.fractionComplete = abs(adjustedY) / 50
    }
    
    
    func panGestureChange(gesture: UIPanGestureRecognizer) {

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

                velocity = gesture.velocity(in: vc.view).y

                if ( (direction == .top && adjustedY > DISMISS_POINT_V)
                    || (direction == .bottom && adjustedY < -DISMISS_POINT_V) ) {
                    commit()
                }
                else { reset() }
            }
            
            
        }
    }
    
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    var isInteractiveDismissToolbar : Bool = false
    var interactiveDismissToolbarStartPoint : CGPoint = .zero

}
