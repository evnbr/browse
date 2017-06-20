//
//  WebViewController+InteractiveDismiss.swift
//  browse
//
//  Created by Evan Brooks on 6/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

extension WebViewController {

    func cancelScroll() {
        webView.scrollView.isScrollEnabled = false
        if webView.scrollView.contentOffset.y < 0 {
            webView.scrollView.contentOffset.y = 0
        }
        webView.scrollView.isScrollEnabled = true
    }
    
    var isInteractiveDismiss : Bool = false
    var interactiveDismissStartPoint : CGPoint = .zero
    var interactiveDismissStartScroll : CGPoint = .zero
    
    func dismissPan(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            let scrollY = webView.scrollView.contentOffset.y
            let endY = webView.scrollView.contentSize.height - webView.bounds.height
            
            if scrollY < 0 || scrollY > endY {
                isInteractiveDismiss = true
                interactiveDismissStartPoint = .zero
                interactiveDismissStartScroll = webView.scrollView.contentOffset
                cancelScroll()
            }
        }
            
        else if gesture.state == .changed {
            let gesturePos = gesture.translation(in: webView)
            
            if isInteractiveDismiss {
                let adjustedY : CGFloat = gesturePos.y - interactiveDismissStartPoint.y
                
                cardView.frame.origin.y = adjustedY > 0 ? adjustedY : adjustedY * -0.2
                cardView.frame.size.height = max(view.frame.height - TOOLBAR_H - (abs(adjustedY) * 1.2), THUMB_H * 1.1)
                
                if adjustedY < 0 {
                    webView.scrollView.contentOffset.y = interactiveDismissStartScroll.y - adjustedY
                }
                
                let progress = 1 - (abs(adjustedY) / 100)
                toolbar.alpha = progress
                
                let revealProgress = abs(adjustedY) / 200
                home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.setNeedsStatusBarAppearanceUpdate()
                })
            }
            else {
                
                let scrollY = webView.scrollView.contentOffset.y
                let endY = webView.scrollView.contentSize.height - webView.bounds.height
                
                if scrollY < 0 || scrollY > endY {
                    isInteractiveDismiss = true
                    interactiveDismissStartPoint = gesturePos
                    interactiveDismissStartScroll = webView.scrollView.contentOffset
                    cancelScroll()
                }
            }
        }
            
        else if gesture.state == .ended {
            if isInteractiveDismiss {
                let gestureY = gesture.translation(in: webView).y
                if abs(gestureY) > 100 {
                    dismissSelf()
                }
                else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.cardView.frame = self.cardViewDefaultFrame
                        self.setNeedsStatusBarAppearanceUpdate()
                        self.toolbar.alpha = 1
                        self.home.navigationController?.view.alpha = 0
                    })
                }
                isInteractiveDismiss = false
            }
            
            
        }
    }
    
    var isInteractiveDismissToolbar : Bool = false
    var interactiveDismissToolbarStartPoint : CGPoint = .zero
    
    func toolbarDismissPan(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            // do nothing until the gesture gets to -20
        }
            
        else if gesture.state == .changed {
            let gesturePos = gesture.translation(in: webView)
            
            if isInteractiveDismissToolbar {
                let adjustedY : CGFloat = gesturePos.y - interactiveDismissToolbarStartPoint.y
                
                cardView.frame.size.height = max(view.frame.height - TOOLBAR_H - (-adjustedY * 1.2), THUMB_H)
                cardView.frame.origin.y = adjustedY * -0.2
                
                let progress = 1 - (abs(adjustedY) / 100)
                toolbar.alpha = progress
                
                let revealProgress = abs(adjustedY) / 400
                home.navigationController?.view.alpha = revealProgress
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.setNeedsStatusBarAppearanceUpdate()
                })
            }
            else {
                if gesturePos.y < -20 {
                    isInteractiveDismissToolbar = true
                    interactiveDismissToolbarStartPoint = gesturePos
                    
                    cancelScroll()
                }
            }
            
        }
            
        else if gesture.state == .ended {
            if isInteractiveDismissToolbar {
                let gestureY = gesture.translation(in: view).y
                if gestureY < -100 {
                    dismissSelf()
                }
                else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.cardView.frame = self.cardViewDefaultFrame
                        self.toolbar.alpha = 1
                        self.home.navigationController?.view.alpha = 0
                    })
                }
                isInteractiveDismissToolbar = false
            }
            
            
        }
    }

}
