//
//  BrowserViewInteractiveDismiss.swift
//  browse
//
//  Created by Evan Brooks on 6/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

enum GestureNavigationDirection {
    case top
    case bottom
    case left
    case right
}

enum GestureNavigationAction {
    case back
    case forward
    case toParent
}

func clip(_ val: CGFloat) -> CGFloat {
    return max(0, min(1, val))
}

func blend(from: CGFloat, to: CGFloat, by pct: CGFloat) -> CGFloat {
    return from + (to - from) * pct;
}


extension UIScrollView {
    var isScrollable : Bool {
        return contentSize.height > bounds.height
    }
    var isOverScrolledTop : Bool {
        return contentOffset.y < 0
    }
    var isOverScrolledBottom : Bool {
        return contentOffset.y > (contentSize.height - bounds.height)
    }
}

class BrowserGestureController : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : BrowserViewController!
    var home : HomeViewController!
    
    var view : UIView!
    var toolbar : UIView!
    var statusBar : UIView!
    var cardView : UIView!
    
    var direction : GestureNavigationDirection!
    var velocity : CGFloat = 0
    
    var mockCardView: UIView!
    let mockCardViewSpacer : CGFloat = 12
    
    var isInteractiveDismiss : Bool = false
    var startPoint : CGPoint = .zero
    var startScroll : CGPoint = .zero
    
    let dismissPointX : CGFloat = 150
    let backPointX : CGFloat = 120
    let dismissPointY : CGFloat = 120

    var canGoBackToParent : Bool {
        return !vc.webView.canGoBack && vc.browserTab?.parentTab != nil
    }
    
    init(for vc : BrowserViewController) {
        super.init()
        
        self.vc = vc
        view = vc.view
        home = vc.home
        statusBar = vc.statusBar
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        mockCardView = UIView(frame: cardView.bounds)
        mockCardView.layer.cornerRadius = cardView.layer.cornerRadius
        mockCardView.backgroundColor = .white
        mockCardView.frame.origin.x = -mockCardView.frame.width
        mockCardView.clipsToBounds = true
        view.addSubview(mockCardView)
        view.bringSubview(toFront: cardView)
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(verticalPan(gesture:)))
        dismissPanner.cancelsTouchesInView = false
        dismissPanner.delaysTouchesBegan = false
        view.addGestureRecognizer(dismissPanner)
        
        let backDismissPan = UIScreenEdgePanGestureRecognizer()
        backDismissPan.delegate = self
        backDismissPan.edges = .left
        backDismissPan.addTarget(self, action: #selector(leftEdgePan(gesture:)))
        backDismissPan.cancelsTouchesInView = false
        backDismissPan.delaysTouchesBegan = false
        view.addGestureRecognizer(backDismissPan)
        
        let forwardDismissPan = UIScreenEdgePanGestureRecognizer()
        forwardDismissPan.delegate = self
        forwardDismissPan.edges = .right
        forwardDismissPan.addTarget(self, action: #selector(rightEdgePan(gesture:)))
        forwardDismissPan.cancelsTouchesInView = false
        forwardDismissPan.delaysTouchesBegan = false
        view.addGestureRecognizer(forwardDismissPan)
    }
        
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        vc.showToolbar()
    }
    
    var prevScrollY : CGFloat = 0
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // If navigated to page that is not scrollable
        if scrollView.contentOffset.y == 0
        && !scrollView.isScrollable
        && !vc.isShowingToolbar {
            vc.showToolbar(animated: false)
        }
        
        if scrollView.isScrollable && scrollView.isOverScrolledTop {
            if scrollView.isDecelerating {
                vc.webView.scrollView.backgroundColor = vc.statusBar.backgroundColor
            }
            else {
                scrollView.contentOffset.y = 0
            }
        }
        else if isInteractiveDismiss {
            scrollView.contentOffset.y = max(startScroll.y, 0)
        }
        
        let scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y
        
        if scrollView.isDragging
        && scrollView.isTracking
        && scrollView.isScrollable
        && !vc.isDisplayingSearch
//        && !scrollView.isDecelerating
        && !scrollView.isOverScrolledTop
        && !scrollView.isOverScrolledBottom
        && !vc.webView.isLoading {
            let newH = vc.toolbar.bounds.height - scrollDelta
            let toolbarH = max(0, min(Const.shared.toolbarHeight, newH))
            let pct = toolbarH / Const.shared.toolbarHeight
            
            vc.toolbarHeightConstraint.constant = toolbarH
            
            let inset = -Const.shared.toolbarHeight + toolbarH
            scrollView.contentInset.bottom = inset
            scrollView.scrollIndicatorInsets.bottom = inset

            let alpha = pct * 4 - 3
            vc.locationBar.alpha = alpha
            vc.backButton.alpha = alpha
            vc.tabButton.alpha = alpha

            
//            }
//            else {
//                scrollView.contentInset.bottom = toolbarH
//            }
        }
    }
    
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !scrollView.isOverScrolledTop else { return }
        guard !scrollView.isOverScrolledBottom else { return }

        if vc.toolbar.bounds.height < (Const.shared.toolbarHeight / 2) {
            vc.hideToolbar()
        }
        else {
            vc.showToolbar()
        }
    }
    
    func horizontalChange(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isInteractiveDismiss && (direction == .left || direction == .right) else { return }
        
        let gesturePos = gesture.translation(in: view)
        
        let revealProgress = min(abs(gesturePos.x) / 200, 1)
        
        let rad = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.layer.cornerRadius = rad
            mockCardView.layer.cornerRadius = rad
        }

        let adjustedX = gesturePos.x
        
        let yGestureInfluence = gesturePos.y * 0.7
        cardView.center.x = view.center.x + adjustedX


        if direction == .left {
            if vc.webView.canGoBack {
                
                let verticalProgress = clip(yGestureInfluence / 200)
                
                cardView.center.x = view.center.x + blend(from: adjustedX, to: elasticLimit(adjustedX), by: verticalProgress)
                
                let s = 1 - verticalProgress * 0.4
                cardView.transform = CGAffineTransform(scaleX: s, y: s)

                if yGestureInfluence < dismissPointY {
                    let mockX = cardView.center.x - mockCardView.bounds.width - mockCardViewSpacer;
                    if mockCardView.frame.origin.x + mockCardView.frame.width < 0 {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.mockCardView.center.x = mockX
                        })
                    }
                    else {
                        mockCardView.center.x = mockX
                    }
                    cardView.center.y = view.center.y + (abs(yGestureInfluence) > 20
                        ? (yGestureInfluence - 20) * 0.3 : 0)
                }
                else {
                    let constrained = dismissPointY * 0.3
                    UIView.animate(withDuration: 0.2, animations: {
                        self.mockCardView.center.x = self.view.center.x - self.mockCardView.bounds.width - self.mockCardViewSpacer
                    })
                    cardView.center.y = self.view.center.y + constrained + (yGestureInfluence - dismissPointY)
                }
                
                let vProgress = abs(cardView.frame.origin.y / 200)
                home.navigationController?.view.alpha = vProgress * 0.7 // alpha is 0 ... 0.4
//                home.setThumbPosition(expanded: true, offsetY: cardView.frame.origin.y, offsetHeight: 0)
            }
            else {
                // COPY PASTED A
                home.navigationController?.view.alpha = revealProgress * 0.7 // alpha is 0 ... 0.4

                let prog = abs(gesturePos.x) / view.bounds.width
                let s = 1 - prog * 0.6
                let yHint : CGFloat = 20
                let yShift = prog * yHint + yGestureInfluence
                cardView.center.x = view.center.x + elasticLimit(elasticLimit(adjustedX))
                cardView.center.y = view.center.y + yShift
                cardView.transform = CGAffineTransform(scaleX: s, y: s)
                
//                home.setThumbPosition(expanded: true, offsetY: cardView.frame.origin.y, offsetHeight: cardView.bounds.height * (1 - s) )
                
                if canGoBackToParent {
                    mockCardView.frame.origin.x = 0
                    mockCardView.frame.size.height = THUMB_H
                    mockCardView.frame.origin.y = -mockCardView.frame.height + prog * yHint - mockCardViewSpacer + yGestureInfluence
                }
            }
        }
        else if direction == .right
        && vc.webView.canGoForward {
            mockCardView.frame.origin.x = adjustedX + mockCardView.frame.width + mockCardViewSpacer
        }
        else {
            // COPY PASTED A
            home.navigationController?.view.alpha = revealProgress * 0.7 // alpha is 0 ... 0.4
            cardView.frame.origin.x = elasticLimit(adjustedX)
            
            let prog = abs(gesturePos.x) / view.bounds.width
            let s = 1 - prog * 0.6
            let yHint : CGFloat = 20
            let yShift = prog * yHint + yGestureInfluence
            cardView.center.x = view.center.x + elasticLimit(elasticLimit(adjustedX))
            cardView.center.y = view.center.y + yShift
            cardView.transform = CGAffineTransform(scaleX: s, y: s)
            
//            home.setThumbPosition(expanded: true, offsetY: cardView.frame.origin.y)
        }
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func horizontalEnd(_ gesture: UIScreenEdgePanGestureRecognizer) {
        endGesture()

        let gesturePos = gesture.translation(in: view)
        
        if (direction == .left || direction == .right)
        && cardView.center.y > view.center.y + dismissPointY
        && !canGoBackToParent {
            commitDismiss()
        }
        else if gesturePos.x > backPointX {
            if vc.webView.canGoBack {
                if mockCardView.frame.origin.x + mockCardView.frame.width > backPointX {
                    commit(action: .back)
                }
                else { commitDismiss() }
            }
            else if canGoBackToParent {
                if cardView.center.y > view.center.y + dismissPointY {
                    commit(action: .toParent)
                }
                else { commitDismiss() }
            }
            else { commitDismiss() }
        }
        else if gesturePos.x < -backPointX {
            if vc.webView.canGoForward { commit(action: .forward) }
            else { commitDismiss() }
        }
        else {
            reset()
        }
    }
    
    @objc func leftEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {

        if gesture.state == .began {
            direction = .left
            startGesture()
            vc.showToolbar()
            if !vc.webView.canGoBack {
                if let parent = vc.browserTab?.parentTab {
                    if let img = parent.history.current?.snapshot {
                        let snap = UIImageView(image: img)
                        snap.sizeToFit()
                        mockCardView.addSubview(snap)
                    }
                }
            }
        }
        else if gesture.state == .changed {
            horizontalChange(gesture)
        }
        else if gesture.state == .ended {
            horizontalEnd(gesture)
        }
    }
    
    @objc func rightEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            direction = .right
            startGesture()
            vc.showToolbar()
        }
        else if gesture.state == .changed {
            horizontalChange(gesture)
        }
        else if gesture.state == .ended {
            horizontalEnd(gesture)
        }
    }

    
    func considerStarting(gesture: UIPanGestureRecognizer) {
        let scrollView = vc.webView.scrollView
        let scrollY = scrollView.contentOffset.y
        
        let gesturePos = gesture.translation(in: view)
        
        if scrollView.isScrollable {
            // Body scrollable, cancel at scrollPos 0
            if scrollY == 0 && gesturePos.y > 0 {
                direction = .top
                startPoint = gesturePos
                startGesture()
            }
//            else if scrollView.isOverScrolledBottom {
//                direction = .bottom
//                startPoint = gesturePos
//                startGesture()
//            }
        }
        else {
            // Inner div is scrollable, body always scrollPos, 0 cancel at scrollPos -1
            if scrollY < 0 && gesturePos.y > 0 {
                direction = .top
                startPoint = gesturePos
                startGesture()
            }
        }
        
    }
    
    
    var shouldRestoreKeyboard : Bool = false
    
    var tabSwitcherStartScroll : CGFloat = 0

    func startGesture() {
        isInteractiveDismiss = true
        startScroll = vc.webView.scrollView.contentOffset
        
        tabSwitcherStartScroll = home.collectionView?.contentOffset.y ?? 0
        
        if vc.isDisplayingSearch {
            vc.hideSearch()
        }
    }
    
    
    func endGesture() {
        isInteractiveDismiss = false
    }
    
    func commitDismiss() {
        vc.dismiss(animated: true, completion: nil)
    }
    
    func swapTo(childTab: BrowserTab) {
        let parentMock = cardView.snapshotView(afterScreenUpdates: false)!
        parentMock.contentMode = .top
        parentMock.clipsToBounds = true
        parentMock.layer.cornerRadius = Const.shared.cardRadius
        
        vc.view.insertSubview(parentMock, belowSubview: cardView)
        vc.setTab(childTab)
        cardView.center.y = view.center.y + cardView.bounds.height + mockCardViewSpacer
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                self.cardView.center = self.view.center
                parentMock.frame.size.height = THUMB_H
                parentMock.frame.origin.y = -parentMock.frame.height - self.mockCardViewSpacer
            }, completion: { done in
                parentMock.removeFromSuperview()
            }
        )
    }
    
    func commit(action: GestureNavigationAction) {
        let mockContent = cardView.snapshotView(afterScreenUpdates: false)
        if mockContent != nil {
            mockCardView.addSubview(mockContent!)
        }
        cardView.backgroundColor = .white
        vc.toolbar.backgroundColor = .white
        vc.statusBar.backgroundColor = .white
        
        if action == .back {
            vc.webView.goBack()
            vc.hideUntilNavigationDone = true
        }
        else if action == .forward {
            vc.webView.goForward()
            vc.hideUntilNavigationDone = true
        }
        else if action == .toParent {
            if let parent = self.vc.browserTab?.parentTab {
                vc.setTab(parent)
            }
        }
        
        // Swap pos

        let cardOrigin = cardView.center
        if (action == .toParent) {
            cardView.bounds.size = mockCardView.bounds.size
            cardView.alpha = mockCardView.alpha
            mockCardView.bounds.size = vc.cardViewDefaultFrame.size
            mockCardView.alpha = 1
        }
        cardView.center = mockCardView.center
        mockCardView.center = cardOrigin
        
        mockCardView.transform = cardView.transform
        cardView.transform = .identity

        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
            if action == .toParent {
                self.cardView.alpha = 1
                self.cardView.bounds.size = self.vc.cardViewDefaultFrame.size
                self.cardView.center = self.vc.view.center
                
                self.mockCardView.center.x = self.vc.view.center.x
                self.mockCardView.center.y = self.vc.view.center.y + self.cardView.bounds.height
            }
            else if action == .back {
                self.cardView.center = self.view.center
                self.mockCardView.frame.origin.x = self.cardView.frame.width + self.mockCardViewSpacer
            }
            else if action == .forward {
                self.cardView.center = self.view.center
                self.mockCardView.frame.origin.x = -self.cardView.frame.width - self.mockCardViewSpacer
            }
            self.cardView.layer.cornerRadius = Const.shared.cardRadius
            self.cardView.transform = .identity

            self.mockCardView.layer.cornerRadius = Const.shared.cardRadius
            self.mockCardView.transform = .identity

        }, completion: { completed in
            
            self.vc.resetSizes()
            self.vc.view.bringSubview(toFront: self.cardView)
            
            self.mockCardView.frame.origin.x = -self.mockCardView.frame.width
            self.mockCardView.frame.origin.y = 0

            mockContent?.removeFromSuperview()
            self.mockCardView.subviews.forEach { $0.removeFromSuperview() }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.home.setNeedsStatusBarAppearanceUpdate()
            })
        })
    }

    func reset(atVelocity vel : CGFloat = 0.0) {
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                self.vc.resetSizes()
                self.vc.setNeedsStatusBarAppearanceUpdate()
                
                self.home.navigationController?.view.alpha = 0
                self.home.setThumbPosition(expanded: true)
                
                let w = self.mockCardView.frame.width + self.mockCardViewSpacer
                if self.mockCardView.frame.origin.y < 0 {
                    self.mockCardView.alpha = 0
                    self.mockCardView.frame.origin.y = -self.mockCardView.frame.height
                }
                else if self.mockCardView.frame.origin.x > 0 {
                    self.mockCardView.frame.origin.x = w
                } else {
                    self.mockCardView.frame.origin.x = -w
                }
                self.cardView.layer.cornerRadius = Const.shared.cardRadius
                self.mockCardView.layer.cornerRadius = Const.shared.cardRadius
            }, completion: { _ in
                self.mockCardView.alpha = 1
                self.mockCardView.bounds.size = self.vc.cardViewDefaultFrame.size
                self.mockCardView.frame.origin.x = -self.mockCardView.frame.width
                self.mockCardView.frame.origin.y = 0
            }
        )
    }
    
    func elasticLimit(_ val : CGFloat, constant: CGFloat = 150) -> CGFloat {
        let resist = 1 - log10(1 + abs(val) / 150) // 1 ... 0.5
        return val * resist
    }
    
    func verticalChange(gesture: UIPanGestureRecognizer) {
        
        let gesturePos = gesture.translation(in: view)
        let adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
            endGesture()
            vc.resetSizes()
            return
        }
        
        cardView.center.y = view.center.y + adjustedY
        
        if adjustedY > 0 {
            vc.toolbarHeightConstraint.constant = max(0, Const.shared.toolbarHeight)
        }
        
//        home.setThumbPositiorn(expanded: true, offsetY: adjustedY)
        
        let revealProgress = abs(adjustedY) / 200
        home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
        
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.layer.cornerRadius = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        }
        
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
    }
    
    
    @objc func verticalPan(gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            considerStarting(gesture: gesture)
        }
        else if gesture.state == .changed {
            if isInteractiveDismiss && !(direction == .left || direction == .right) {
                verticalChange(gesture: gesture)
            }
            else if !isInteractiveDismiss {
                considerStarting(gesture: gesture)
            }
        }
        else if gesture.state == .ended {
            if isInteractiveDismiss && !(direction == .left || direction == .right) {
                endGesture()
                
                let gesturePos = gesture.translation(in: view)
                let adjustedY : CGFloat = gesturePos.y - startPoint.y

                let vel = gesture.velocity(in: vc.view)
                
                
                if (direction == .top && (vel.y > 600 || adjustedY > dismissPointY)) {
                    commitDismiss()
                }
                else if (direction == .bottom && (vel.y < -600 || adjustedY < -dismissPointY)) {
                    commitDismiss()
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
    
}
