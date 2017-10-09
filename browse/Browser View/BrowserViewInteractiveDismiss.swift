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

class BrowserViewInteractiveDismiss : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : BrowserViewController!
    var home : HomeViewController!
    
    var view : UIView!
    var toolbar : UIView!
    var statusBar : UIView!
    var cardView : UIView!
    
    var direction : GestureNavigationDirection!
    var velocity : CGFloat = 0
    
    var mockCardView: UIView!
    var toParentIcon : UIView!
    let mockCardViewSpacer : CGFloat = 20
    
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
        
        let toParentImage = UIImage(named: "to-parent")?.withRenderingMode(.alwaysTemplate)
        toParentIcon = UIImageView(image: toParentImage)
        toParentIcon.tintColor = .white
        toParentIcon.frame.origin = CGPoint(x: 0, y: cardView.frame.height / 2)
        toParentIcon.alpha = 0
        view.addSubview(toParentIcon)
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
        dismissPanner.cancelsTouchesInView = true
        view.addGestureRecognizer(dismissPanner)
        
        let backDismissPan = UIScreenEdgePanGestureRecognizer()
        backDismissPan.delegate = self
        backDismissPan.edges = .left
        backDismissPan.addTarget(self, action: #selector(backGestureChange(gesture:)))
        backDismissPan.cancelsTouchesInView = true
        view.addGestureRecognizer(backDismissPan)
        
        let forwardDismissPan = UIScreenEdgePanGestureRecognizer()
        forwardDismissPan.delegate = self
        forwardDismissPan.edges = .right
        forwardDismissPan.addTarget(self, action: #selector(forwardGestureChange(gesture:)))
        forwardDismissPan.cancelsTouchesInView = true
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
        && scrollView.isScrollable
        && !vc.isDisplayingSearch
        && !scrollView.isOverScrolledTop
        && !scrollView.isOverScrolledBottom
        && !vc.webView.isLoading {
            let newH = vc.toolbar.frame.height - scrollDelta
            let toolbarH = max(0, min(Const.shared.toolbarHeight, newH))
            
            vc.toolbarHeightConstraint.constant = toolbarH
            vc.heightConstraint.constant = -toolbarH - Const.shared.statusHeight
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView.contentOffset.y > 0 else { return }
        if vc.toolbar.frame.height < (Const.shared.toolbarHeight / 2) {
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
        home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
        
        let scale = PRESENT_TAB_BACK_SCALE + revealProgress * 0.5 * (1 - PRESENT_TAB_BACK_SCALE)
        home.navigationController?.view.transform = CGAffineTransform(scaleX: scale, y: scale)
        
        let adjustedX = gesturePos.x
        
        let yGestureInfluence = gesturePos.y * 0.7
        cardView.frame.origin.x = adjustedX


        if direction == .left {
            if vc.webView.canGoBack {
                if yGestureInfluence < dismissPointY {
                    mockCardView.frame.origin.x = adjustedX - mockCardView.frame.width - mockCardViewSpacer
                    cardView.frame.origin.y = 0 + yGestureInfluence * 0.3
                    mockCardView.frame.origin.y = 0 + yGestureInfluence * 0.2
                }
                else {
                    UIView.animate(withDuration: 0.1, animations: {
                        self.mockCardView.frame.origin.x = -self.mockCardView.frame.width - self.mockCardViewSpacer
                    })
                    cardView.frame.origin.y = 0 + yGestureInfluence
                }
            }
            else if canGoBackToParent {
                home.navigationController?.view.alpha = 0
                cardView.frame.origin.x = elasticLimit(adjustedX)
                
                let prog = abs(gesturePos.x) / 300
                let yHint : CGFloat = 60

                mockCardView.frame.origin.x = 0
                mockCardView.frame.origin.y = -mockCardView.frame.height + prog * yHint - mockCardViewSpacer + yGestureInfluence
//                mockCardView.frame.size.height = prog * 200 - mockCardViewSpacer
                toParentIcon.alpha = revealProgress
                toParentIcon.frame.origin.x = cardView.frame.origin.x / 2
                
                cardView.frame.origin.y = prog * yHint + yGestureInfluence
            }
        }
        else if direction == .right
        && vc.webView.canGoForward {
            mockCardView.frame.origin.x = adjustedX + mockCardView.frame.width + mockCardViewSpacer
        }
    }
    
    func horizontalEnd(_ gesture: UIScreenEdgePanGestureRecognizer) {
        endGesture()

        let gesturePos = gesture.translation(in: view)
        
        if (direction == .left || direction == .right)
        && cardView.frame.origin.y > dismissPointY
        && !canGoBackToParent {
            commitDismiss()
        }
        else if gesturePos.x > backPointX {
            if (vc.webView.canGoBack) {
                commit(action: .back)
            }
            else if canGoBackToParent {
                commit(action: .toParent)
            }
            else {
                commitDismiss()
            }
        }
        else if gesturePos.x < -backPointX {
            if (vc.webView.canGoForward) {
                commit(action: .forward)
            }
            else {
                commitDismiss()
            }
        }
        else {
            reset()
        }
    }
    
    @objc func backGestureChange(gesture:UIScreenEdgePanGestureRecognizer) {

        if gesture.state == .began {
            direction = .left
            startGesture()
            vc.showToolbar()
            if !vc.webView.canGoBack {
                if let parent = vc.browserTab?.parentTab {
                    if let snap = parent.webSnapshot?.snapshotView(afterScreenUpdates: false) {
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
    
    @objc func forwardGestureChange(gesture:UIScreenEdgePanGestureRecognizer) {
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
            else if scrollView.isOverScrolledBottom {
                direction = .bottom
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
        
    }
    
    
    var shouldRestoreKeyboard : Bool = false
    func startGesture() {
        isInteractiveDismiss = true
        startScroll = vc.webView.scrollView.contentOffset
        
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
    
    func commit(action: GestureNavigationAction) {
        let mockContent = cardView.snapshotView(afterScreenUpdates: false)
        if mockContent != nil { mockCardView.addSubview(mockContent!) }
        cardView.backgroundColor = .white
        vc.toolbar.backgroundColor = .white
        vc.statusBar.backgroundColor = .white
        
        let webViewToHide = vc.webView
        webViewToHide?.alpha = 0
        
        
        if action == .back {
            vc.webView.goBack()
        }
        else if action == .forward {
            vc.webView.goForward()
        }
        else if action == .toParent {
            if let parent = self.vc.browserTab?.parentTab {
                vc.setTab(parent)
            }
        }
        
        // Swap pos

        let cardOrigin = cardView.frame.origin
        if (action == .toParent) {
            cardView.frame.size = mockCardView.frame.size
            mockCardView.frame.size = vc.cardViewDefaultFrame.size
        }
        cardView.frame.origin = mockCardView.frame.origin
        
        mockCardView.frame.origin = cardOrigin
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
            if action == .toParent {
                self.cardView.frame = self.vc.cardViewDefaultFrame
                self.mockCardView.frame.origin.x = 0
                self.mockCardView.frame.origin.y = self.cardView.frame.height
                self.toParentIcon.frame.origin.x = -self.toParentIcon.frame.width
                self.toParentIcon.alpha = 0
            }
            else if action == .back {
                self.cardView.frame.origin = .zero
                self.mockCardView.frame.origin.x = self.cardView.frame.width + self.mockCardViewSpacer
            }
            else if action == .forward {
                self.cardView.frame.origin = .zero
                self.mockCardView.frame.origin.x = -self.cardView.frame.width - self.mockCardViewSpacer
            }
        }, completion: { completed in
            
            self.vc.resetSizes(withKeyboard: self.shouldRestoreKeyboard)
            self.vc.view.bringSubview(toFront: self.cardView)
            
            self.mockCardView.frame.origin.x = -self.mockCardView.frame.width
            self.mockCardView.frame.origin.y = 0

            mockContent?.removeFromSuperview()
            self.mockCardView.subviews.forEach { $0.removeFromSuperview() }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.home.setNeedsStatusBarAppearanceUpdate()
            })
            UIView.animate(withDuration: 0.15, delay: 0.2, animations: {
                webViewToHide?.alpha = 1
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
                self.vc.resetSizes(withKeyboard: self.shouldRestoreKeyboard)
                self.vc.setNeedsStatusBarAppearanceUpdate()
                self.vc.home.navigationController?.view.alpha = 0
                self.home.navigationController?.view.frame.origin.y = 0
                
                let w = self.mockCardView.frame.width + self.mockCardViewSpacer
                if self.mockCardView.frame.origin.y < 0 {
                    self.mockCardView.frame.origin.y = -self.mockCardView.frame.height
                    self.toParentIcon.frame.origin.x = -self.toParentIcon.frame.width
                    self.toParentIcon.alpha = 0
                }
                else if self.mockCardView.frame.origin.x > 0 {
                    self.mockCardView.frame.origin.x = w
                } else {
                    self.mockCardView.frame.origin.x = -w
                }
                self.cardView.layer.cornerRadius = Const.shared.cardRadius
        }, completion: nil)
    }
    
    func elasticLimit(_ val : CGFloat) -> CGFloat {
        let resist = 1 - log10(1 + abs(val) / 150) // 1 ... 0.5
        return val * resist
    }
    
    func update(gesture: UIPanGestureRecognizer) {
        
        let gesturePos = gesture.translation(in: view)
        let adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
            endGesture()
            vc.resetSizes(withKeyboard: shouldRestoreKeyboard)
            return
        }
        
//        adjustedY = elasticLimit(adjustedY)
        
        let statusOffset : CGFloat = 0 // min(Const.shared.statusHeight, (abs(adjustedY) / 300) * Const.shared.statusHeight)
        vc.webView.frame.origin.y = Const.shared.statusHeight - statusOffset
        statusBar.frame.origin.y = 0 - statusOffset
        
        cardView.frame.origin.y = adjustedY
        
//        if adjustedY > 0 {
//            cardView.frame.size.height = view.frame.height - (abs(adjustedY))
//        }
        
        let revealProgress = abs(adjustedY) / 200
        home.navigationController?.view.alpha = revealProgress * 0.4 // alpha is 0 ... 0.4
        let scale = PRESENT_TAB_BACK_SCALE + revealProgress * 0.5 * (1 - PRESENT_TAB_BACK_SCALE)
        
        home.navigationController?.view.transform = CGAffineTransform(scaleX: scale, y: scale)
        
        if let cv = home.collectionView {
            for cell in home.visibleCellsAbove {
                if let idx = cv.indexPath(for: cell)?.item {
                    cell.frame.origin.y = (adjustedY / 4) * CGFloat(idx) + cv.contentOffset.y + Const.shared.statusHeight
                }
            }
        }
        
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.layer.cornerRadius = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        }
        
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
    }
    
    
    @objc func panGestureChange(gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            considerStarting(gesture: gesture)
        }
        else if gesture.state == .changed {
            if isInteractiveDismiss && !(direction == .left || direction == .right) {
                update(gesture: gesture)
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
