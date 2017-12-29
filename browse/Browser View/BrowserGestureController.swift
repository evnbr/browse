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
    var cardView : UIView!
    
    var direction : GestureNavigationDirection!
    var velocity : CGFloat = 0
    
    var mockCardView: UIView!
    let mockCardViewSpacer : CGFloat = 8
    
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
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        mockCardView = UIView(frame: cardView.bounds)
        mockCardView.layer.cornerRadius = Const.shared.cardRadius
        mockCardView.backgroundColor = .white
        mockCardView.clipsToBounds = false
        mockCardView.layer.shadowRadius = 24
        mockCardView.layer.shadowOpacity = 0.16

        
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
            if !scrollView.isDecelerating {
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

            let alpha = pct * 3 - 2
            vc.locationBar.alpha = alpha
            vc.backButton.alpha = alpha
            vc.tabButton.alpha = alpha
            
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
    
    let vProgressScaleMultiplier : CGFloat = 0.3
    let cantGoBackScaleMultiplier : CGFloat = 0.3

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
        
        let yGestureInfluence = gesturePos.y // * 0.7
        cardView.center.x = view.center.x + adjustedX

        let verticalProgress = clip(gesturePos.y  / 200)
        let stackupProgress = 1 - clip((gesturePos.y - 100) / 200)
        
        if direction == .left {
            if vc.webView.canGoBack {
                
                
                let s = 1 - verticalProgress * vProgressScaleMultiplier
                cardView.transform = CGAffineTransform(scaleX: s, y: s)
                mockCardView.transform = cardView.transform

                let scaleFromLeftShift = (1 - s) * cardView.bounds.width / 2
                
                cardView.center.x = view.center.x
                    + blend(from: adjustedX,
                            to: adjustedX, //elasticLimit(adjustedX),
                            by: verticalProgress)
                    - scaleFromLeftShift
                
                cardView.center.y = view.center.y + yGestureInfluence
                
                
                mockCardView.center = self.cardView.center
                mockCardView.center.x -= ( self.cardView.bounds.width * s + mockCardViewSpacer )  * stackupProgress

            }
            else {
                // COPY PASTED A

                let hProgress = abs(gesturePos.x) / view.bounds.width
                let s = 1 - hProgress * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier
                let yHint : CGFloat = 20
                let yShift = hProgress * yHint + yGestureInfluence
                cardView.center.x = view.center.x + elasticLimit(elasticLimit(adjustedX))
                cardView.center.y = view.center.y + yShift
                cardView.transform = CGAffineTransform(scaleX: s, y: s)

                
            }
        }
        else if direction == .right
        && vc.webView.canGoForward {
            
            let s = 1 - verticalProgress * vProgressScaleMultiplier
            cardView.transform = CGAffineTransform(scaleX: s, y: s)
            mockCardView.transform = cardView.transform
            
            let scaleFromRightShift = (1 - s) * cardView.bounds.width / 2
            
            cardView.center.x = view.center.x
                + blend(from: adjustedX,
                        to: adjustedX, //elasticLimit(adjustedX),
                    by: verticalProgress)
                + scaleFromRightShift
            
            cardView.center.y = view.center.y + yGestureInfluence
            
            
            mockCardView.center = self.cardView.center
            mockCardView.center.x += ( self.cardView.bounds.width * s + mockCardViewSpacer )  * stackupProgress
        }
        else {
            // COPY PASTED A
            
            let hProgress = abs(gesturePos.x) / view.bounds.width
            let s = 1 - hProgress * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier
            let yHint : CGFloat = 20
            let yShift = hProgress * yHint + yGestureInfluence
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
        && cardView.center.y > view.center.y + dismissPointY {
            commitDismiss()
        }
        else if gesturePos.x > backPointX {
            if vc.webView.canGoBack {
                if mockCardView.frame.origin.x + mockCardView.frame.width > backPointX {
                    commit(action: .back)
                }
                else { commitDismiss() }
            }
//            else if canGoBackToParent {
//                if cardView.center.y > view.center.y + dismissPointY {
//                    commit(action: .toParent)
//                }
//                else { commitDismiss() }
//            }
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
            
            if vc.webView.canGoBack {
                view.addSubview(mockCardView)
                view.bringSubview(toFront: cardView)
                mockCardView.transform = .identity
                mockCardView.center = vc.view.center
            }
            
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
            vc.webView.scrollView.cancelScroll()
            vc.showToolbar()
            
            if vc.webView.canGoForward {
                view.addSubview(mockCardView)
                view.bringSubview(toFront: cardView)
                mockCardView.transform = .identity
                mockCardView.center = vc.view.center
            }
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
        }
        else {
            // Inner div is scrollable, body always scrollPos, 0 cancel at scrollPos -1
            if scrollY < 0 && gesturePos.y > 0 {
                direction = .top
                startPoint = gesturePos
                startGesture()
            }
        }
//        if canGoBackToParent {
//            view.addSubview(mockCardView)
//            view.bringSubview(toFront: cardView)
//            mockCardView.transform = CGAffineTransform.init(scaleX: 0.9, y: 0.9)
//            mockCardView.center = vc.view.center
//            mockCardView.center.y += Const.shared.statusHeight
//        }
        
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
        self.mockCardView.removeFromSuperview()
        vc.dismiss(animated: true, completion: nil)
    }
    
    func swapTo(childTab: BrowserTab) {
        let parentMock = cardView.snapshotView(afterScreenUpdates: false)!
        parentMock.contentMode = .top
        parentMock.clipsToBounds = true
        parentMock.layer.cornerRadius = Const.shared.cardRadius
        
        vc.view.insertSubview(parentMock, belowSubview: cardView)
        vc.setTab(childTab)
        cardView.center.y = view.center.y + cardView.bounds.height
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                self.cardView.center = self.view.center
                parentMock.center.y += Const.shared.statusHeight
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
        vc.roundedClipView.backgroundColor = .white
        vc.toolbar.backgroundColor = .white
        vc.statusBarFront.backgroundColor = .white
        
        if action == .back {
            vc.webView.goBack()
            vc.hideUntilNavigationDone = true
            view.bringSubview(toFront: mockCardView)
        }
        else if action == .forward {
            vc.webView.goForward()
            vc.hideUntilNavigationDone = true
            view.bringSubview(toFront: cardView)
        }
        else if action == .toParent {
            if let parent = self.vc.browserTab?.parentTab {
                vc.setTab(parent)
            }
            view.bringSubview(toFront: mockCardView)
        }
        
        // Swap pos

        let cardOrigin = cardView.center
        if (action == .toParent) {
            cardView.bounds.size = mockCardView.bounds.size
            cardView.alpha = mockCardView.alpha
            mockCardView.bounds.size = vc.cardViewDefaultFrame.size
            mockCardView.alpha = 1
            mockCardView.center = view.center
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
                self.mockCardView.center.x = self.view.center.x + self.mockCardView.bounds.width + self.mockCardViewSpacer
            }
            else if action == .forward {
                self.cardView.center = self.view.center
                self.mockCardView.center.x = self.view.center.x - self.mockCardView.bounds.width - self.mockCardViewSpacer
            }
            self.cardView.layer.cornerRadius = Const.shared.cardRadius
            self.cardView.transform = .identity

            self.mockCardView.layer.cornerRadius = Const.shared.cardRadius
            self.mockCardView.transform = .identity

        }, completion: { completed in
            
            self.vc.resetSizes()
            self.vc.view.bringSubview(toFront: self.cardView)
            
            mockContent?.removeFromSuperview()
            self.mockCardView.subviews.forEach { $0.removeFromSuperview() }
            self.mockCardView.removeFromSuperview()

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
                
                self.mockCardView.center = self.cardView.center
                self.mockCardView.transform = self.cardView.transform

                self.cardView.layer.cornerRadius = Const.shared.cardRadius
                self.mockCardView.layer.cornerRadius = Const.shared.cardRadius
            }, completion: { _ in
                self.mockCardView.removeFromSuperview()
            }
        )
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
