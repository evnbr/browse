//
//  BrowserViewInteractiveDismiss.swift
//  browse
//
//  Created by Evan Brooks on 6/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import pop

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


class BrowserGestureController : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : BrowserViewController!

    var view : UIView!
    var toolbar : UIView!
    var cardView : UIView!
    
    var direction : GestureNavigationDirection!
    var dismissVelocity : CGPoint?

    var mockCardView: PlaceholderView!
    let mockCardViewSpacer : CGFloat = 8
    
    var mockPositioner : PositionSpringTransition!
    var cardPositioner : PositionSpringTransition!

    var isInteractiveDismiss : Bool = false
    var startPoint : CGPoint = .zero
    var startScroll : CGPoint = .zero
    
    let dismissPointX : CGFloat = 150
    let backPointX : CGFloat = 120
    let dismissPointY : CGFloat = 120

    var feedbackGenerator : UISelectionFeedbackGenerator? = nil
    
    var canGoBackToParent : Bool {
        return !vc.webView.canGoBack && vc.browserTab?.parentTab != nil
    }
    
    init(for vc : BrowserViewController) {
        super.init()
        
        self.vc = vc
        view = vc.view
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        mockCardView = PlaceholderView(frame: cardView.bounds)
        mockPositioner = PositionSpringTransition(view: mockCardView)
        cardPositioner = PositionSpringTransition(view: cardView)
        
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
    var scrollDelta : CGFloat = 0
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
        
        scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y
        
        if scrollView.isDragging
        && scrollView.isTracking
        && scrollView.isScrollable
        && !vc.isDisplayingSearch
        && !scrollView.isOverScrolledTop
        && !scrollView.isOverScrolledBottom
        && !vc.webView.isLoading {
            let newH = vc.toolbar.bounds.height - scrollDelta
            let toolbarH = max(0, min(Const.toolbarHeight, newH))
            let pct = toolbarH / Const.toolbarHeight
            
            vc.toolbarHeightConstraint.constant = toolbarH
            
            let inset = -Const.toolbarHeight + toolbarH
            scrollView.contentInset.bottom = inset
            scrollView.scrollIndicatorInsets.bottom = inset

            let alpha = pct * 3 - 2
            vc.locationBar.alpha = alpha
            vc.backButton.alpha = alpha
            vc.tabButton.alpha = alpha
        }
    }
    
    var dragStartScroll : CGFloat = 0
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartScroll = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !scrollView.isOverScrolledTop else { return }
        guard !scrollView.isOverScrolledBottom else { return }

        let dragAmount = scrollView.contentOffset.y - dragStartScroll
        
        if scrollDelta > 1 {
            vc.hideToolbar()
        }
        else if scrollDelta < -1 {
            vc.showToolbar()
        }
        else if dragAmount > 1 {
            vc.hideToolbar()
        }
        else if dragAmount < -1 {
            vc.showToolbar()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // TODO: Investigate whether this is too expensive, haven't seen problems yet
        vc.updateSnapshot()
    }
    
    let vProgressScaleMultiplier : CGFloat = 0
    let cantGoBackScaleMultiplier : CGFloat = 1.1
    
    var wouldCommitPreviousX = false
    var wouldCommitPreviousY = false

    func horizontalChange(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isInteractiveDismiss && (direction == .left || direction == .right) else { return }
        
        let gesturePos = gesture.translation(in: view)
        
        let revealProgress = min(abs(gesturePos.x) / 200, 1)
        
        let rad = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.radius = rad
            mockCardView.radius = rad
        }

        let adjustedX = gesturePos.x
        
        let wouldCommitX = abs(adjustedX) > dismissPointX
        if wouldCommitX != wouldCommitPreviousX {
            feedbackGenerator?.selectionChanged()
            feedbackGenerator?.prepare()
            wouldCommitPreviousX = wouldCommitX
        }
        let wouldCommitY = abs(gesturePos.y) > dismissPointY
        let wouldCommitYChanged = (wouldCommitY != wouldCommitPreviousY)
        if wouldCommitY != wouldCommitPreviousY {
//            feedbackGenerator?.selectionChanged()
//            feedbackGenerator?.prepare()
//            home.springCards(expanded: !wouldCommitY)
            wouldCommitPreviousY = wouldCommitY
        }

        
        cardView.center.x = view.center.x + adjustedX
        
        let yGestureInfluence = gesturePos.y
        if yGestureInfluence > 0 {
            cardView.center.y = view.center.y + yGestureInfluence
        }
        else {
            cardView.center.y = view.center.y + elasticLimit(yGestureInfluence) * 0.2
        }

        self.vc.gradientOverlay.alpha = gesturePos.y.progress(from: 0, to: 400)

        let verticalProgress = gesturePos.y.progress(from: 0, to: 200).clip()
        var s : CGFloat = 1
        
        if direction == .left {
            if vc.webView.canGoBack || vc.browserTab!.canGoBackToParent {
                s = (verticalProgress * vProgressScaleMultiplier).reverse()
                cardView.scale = s
                
                let scaleFromLeftShift = (1 - s) * cardView.bounds.width / 2
                
                cardView.center.x = view.center.x
                    + verticalProgress.blend(from: adjustedX, to: elasticLimit(adjustedX))
                    - scaleFromLeftShift
                
                let isToParent = !vc.webView.canGoBack
                let offsetY = view.center.y - cardView.center.y
                mockPositioner.end = !isToParent
                    ? CGPoint(
                        x: cardView.center.x - view.bounds.width / 2 - cardView.bounds.width * s / 2 - mockCardViewSpacer,
                        y: view.center.y)
                    : CGPoint(
                        x: view.center.x,
                        y: view.center.y - offsetY * 0.5)
                    
                mockPositioner.start = !isToParent
                    ? CGPoint(x: view.center.x - view.bounds.width, y: view.center.y)
                    : cardView.center
                mockPositioner.update()
                
                if isToParent {
                    let parentPct = adjustedX.progress(from: 0, to: 800)
                    mockCardView.overlay.alpha = parentPct.reverse()
                    mockCardView.scale = 1 - parentPct.reverse() * 0.05
                }
                
                mockPositioner.springState(gesturePos.y > dismissPointY ? .start : .end)
            }
            else {
                // COPY PASTED A
                let hProg = abs(elasticLimit(gesturePos.x)) / view.bounds.width
                s = 1 - hProg * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier
                
                let spaceW = cardView.bounds.width * ( 1 - s )
                cardView.center.x = view.center.x + spaceW * 0.4
                cardView.scale = s
            }
        }
        else if direction == .right
        && vc.webView.canGoForward {
            
            s = 1 - verticalProgress * vProgressScaleMultiplier
            cardView.scale = s
            
            let scaleFromRightShift = (1 - s) * cardView.bounds.width / 2
            
            cardView.center.x = view.center.x
                + verticalProgress.blend(from: adjustedX, to: elasticLimit(adjustedX))
                + scaleFromRightShift
            
            mockPositioner.end = CGPoint(
                x: cardView.center.x + view.bounds.width / 2 + cardView.bounds.width * s / 2 + mockCardViewSpacer,
                y: view.center.y
            )
            mockPositioner.start = CGPoint(x: view.center.x + view.bounds.width, y: view.center.y)
            mockPositioner.update()
            mockPositioner.springState(gesturePos.y > dismissPointY ? .start : .end)
        }
        else {
            // COPY PASTED A
            
            let hProg = abs(elasticLimit(gesturePos.x)) / view.bounds.width
            s = 1 - hProg * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier

            let spaceW = cardView.bounds.width * ( 1 - s )
            cardView.center.x = view.center.x - spaceW * 0.4
            cardView.scale = s
        }
        
        
        vc.home.setThumbPosition(
//            switcherProgress: gesturePos.y.progress(from: 100, to: 800) + abs(adjustedX).progress(from: 0, to: 400),
            switcherProgress: cardView.frame.origin.y.progress(from: 0, to: 600),
            cardOffset: CGPoint(
                x: view.center.x - cardView.center.x,
                y: view.center.y - cardView.center.y
            ),
            scale: s
        )
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func horizontalEnd(_ gesture: UIScreenEdgePanGestureRecognizer) {
        endGesture()
        feedbackGenerator = nil

        let gesturePos = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)
        
        if (direction == .left || direction == .right)
        && cardView.center.y > view.center.y + dismissPointY {
            commitDismiss(velocity: vel)
        }
        else if gesturePos.x > backPointX {
            if vc.webView.canGoBack
            && mockCardView.frame.origin.x + mockCardView.frame.width > backPointX {
                vc.webView.goBack()
                animateCommit(action: .back, velocity: vel)
                vc.hideUntilNavigationDone()
            }
            else if vc.browserTab!.canGoBackToParent
            && gesturePos.x > backPointX{
                if let parentTab = vc.browserTab?.parentTab {
                    vc.updateSnapshot {
                        let vc = self.vc!
                        self.mockCardView.imageView.image = vc.browserTab!.history.current?.snapshot
                        vc.setTab(parentTab)
                        self.animateCommit(action: .toParent)
                        vc.home.moveTabToEnd(parentTab)
                    }
                }
            }
            else {
                commitDismiss(velocity: vel)
            }
        }
        else if gesturePos.x < -backPointX {
            if vc.webView.canGoForward {
                vc.webView.goForward()
                animateCommit(action: .forward, velocity: vel)
                vc.hideUntilNavigationDone()
            }
            else {
                commitDismiss(velocity: vel)
            }
        }
        else {
            reset(velocity: vel)
        }
    }
    
    func resetMockCardView() {
        mockCardView.transform = .identity
        mockCardView.center = vc.view.center
        mockCardView.bounds = cardView.bounds
    }
    
    @objc func leftEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {

        if gesture.state == .began {
            direction = .left
            startGesture()
            vc.showToolbar()
            
            if vc.webView.canGoBack {
                resetMockCardView()
                if let backItem = vc.webView.backForwardList.backItem,
                    let page = vc.browserTab?.historyPageMap[backItem] {
                    mockCardView.setPage(page)
                }
                view.addSubview(mockCardView)
                view.bringSubview(toFront: cardView)
            }
            else {
                if let parent = vc.browserTab?.parentTab {
                    if let parentPage = parent.history.current {
                        view.insertSubview(mockCardView, belowSubview: cardView)
                        mockCardView.setPage(parentPage)
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
                resetMockCardView()
                if let fwdItem = vc.webView.backForwardList.forwardItem,
                    let page = vc.browserTab?.historyPageMap[fwdItem] {
                    mockCardView.setPage(page)
                }
                view.addSubview(mockCardView)
                view.bringSubview(toFront: cardView)
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
            // Inner div is scrollable, body always scrollPos 0, cancel at scrollPos -1
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
        wouldCommitPreviousX = false
        wouldCommitPreviousY = false
        mockPositioner.setState(.end)
        startScroll = vc.webView.scrollView.contentOffset
                
        vc.webView.scrollView.showsVerticalScrollIndicator = false
        vc.browserTab?.updateSnapshot()
        
        
//        feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator?.prepare()
    }
    
    
    func endGesture() {
        isInteractiveDismiss = false
    }
    
    func commitDismiss(velocity vel: CGPoint) {
        
        dismissVelocity = vel
        self.pop_removeAllAnimations()
        var mockEndCenter = view.center
        let mockShift = mockCardView.bounds.width + mockCardViewSpacer
        if mockCardView.center.x > view.center.x { mockEndCenter.x += mockShift }
        else { mockEndCenter.x -= mockShift }
        mockPositioner.end = mockEndCenter
        mockCardView.springCenter(to: mockEndCenter) { _, _ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        
        vc.dismiss(animated: true) {
            self.dismissVelocity = nil
        }
    }
    
    func swapTo(childTab: BrowserTab) {
        let parentMock = cardView.snapshotView(afterScreenUpdates: false)!
        parentMock.contentMode = .top
        parentMock.clipsToBounds = true
        parentMock.radius = Const.shared.cardRadius
        
        vc.view.insertSubview(parentMock, belowSubview: cardView)
        
        vc.updateSnapshot {
            let vc = self.vc!
            vc.setTab(childTab)
//            vc.cardView.center.y = vc.view.center.y + vc.cardView.bounds.height
            vc.cardView.center.x = vc.view.center.x + vc.cardView.bounds.width

            UIView.animate(
                withDuration: 0.6,
                delay: 0.0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.0,
                options: .allowUserInteraction,
                animations: {
                    vc.cardView.center = vc.view.center
                    parentMock.scale = 0.95
                    parentMock.alpha = 0
            }, completion: { done in
                parentMock.removeFromSuperview()
                vc.home.moveTabToEnd(childTab)
            })
        }
    }
    
    func swapTo(parentTab: BrowserTab) {
        let childMock = cardView.snapshotView(afterScreenUpdates: false)!
        childMock.contentMode = .top
        childMock.clipsToBounds = true
        childMock.radius = Const.shared.cardRadius
        
        vc.view.insertSubview(childMock, aboveSubview: cardView)
        vc.overlay.alpha = 0.8
        vc.cardView.scale = 0.9
        childMock.center = vc.cardView.center

        vc.updateSnapshot {
            let vc = self.vc!
            vc.setTab(parentTab)
            
            UIView.animate(
                withDuration: 0.6,
                delay: 0.0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.0,
                options: .allowUserInteraction,
                animations: {
                    vc.overlay.alpha = 0
                    vc.cardView.center = vc.view.center
                    vc.cardView.transform = .identity
//                    childMock.center.y += vc.cardView.bounds.height
                    childMock.center.x += vc.cardView.bounds.width
            }, completion: { done in
                childMock.removeFromSuperview()
                vc.isSnapshotMode = false // WHy?
                vc.home.moveTabToEnd(parentTab)
            })
        }
    }
    
    func swapCardAndPlaceholder(for action: GestureNavigationAction) {
        // Swap image
        vc.setSnapshot(mockCardView.imageView.image)
        if action != .toParent {
            mockCardView.imageView.image = vc.browserTab?.history.current?.snapshot
        }
        
        // Swap colors
        let statusColor = vc.statusBar.lastColor
        let toolbarColor = vc.toolbar.lastColor
        vc.statusBar.update(toColor: mockCardView.statusView.backgroundColor ?? .white)
        vc.toolbar.update(toColor: mockCardView.toolbarView.backgroundColor ?? .white)
        vc.statusBar.backgroundView.alpha = 1
        vc.toolbar.backgroundView.alpha = 1
        mockCardView.statusView.backgroundColor = statusColor
        mockCardView.toolbarView.backgroundColor = toolbarColor

        
        // Swap pos
        let cardCenter = cardView.center
        cardView.center = mockCardView.center
        mockCardView.center = cardCenter
        
        // Swap transform
        let mockTransform = mockCardView.transform
        mockCardView.transform = cardView.transform
        cardView.transform = mockTransform
        
        // Swap overlay darkness
        let mockAlpha = mockCardView.overlay.alpha
        mockCardView.overlay.alpha = vc.overlay.alpha
        vc.overlay.alpha = mockAlpha
        
        // Swap order
        if action == .toParent {
            view.insertSubview(mockCardView, aboveSubview: cardView)
        }
    }

    func animateCommit(action: GestureNavigationAction, velocity: CGPoint = .zero) {
        
        
        self.pop_removeAllAnimations()
        swapCardAndPlaceholder(for: action)

        cardView.springCenter(to: view.center, at: velocity) {_,_ in
            self.vc.resetSizes()
            self.vc.view.bringSubview(toFront: self.cardView)
            
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.home.setNeedsStatusBarAppearanceUpdate()
            })
            if action == .toParent {
                self.vc.isSnapshotMode = false
            }
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
        }
        
        mockPositioner.end = self.view.center
        let mockShift = mockCardView.bounds.width + mockCardViewSpacer
        if action == .back || action == .toParent { mockPositioner.end.x += mockShift }
        else if action == .forward { mockPositioner.end.x -= mockShift }

        mockCardView.springCenter(to: mockPositioner.end, at: velocity) {_,_ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        mockCardView.springScale(to: 1)
        cardView.springScale(to: 1)
        
        UIView.animate(withDuration: 0.3) {
            self.vc.overlay.alpha = 0
            self.vc.gradientOverlay.alpha = 0
        }
    }

    func reset(velocity: CGPoint) {
        vc.webView.scrollView.cancelScroll()

        // Move card back to center
        cardView.springCenter(to: view.center, at: velocity) {_,_ in
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.home.setNeedsStatusBarAppearanceUpdate()
            })
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
        }
        cardView.springScale(to: 1)

        var mockCenter = self.view.center
        let mockShift = mockCardView.bounds.width + mockCardViewSpacer
        if mockCardView.center.x > view.center.x { mockCenter.x += mockShift }
        else { mockCenter.x -= mockShift }
        
        mockCardView.springCenter(to: mockCenter, at: velocity) {_,_ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        mockCardView.springScale(to: 1)
//        vc.statusHeightConstraint.springConstant(to: Const.statusHeight)
        vc.home.springCards(expanded: false, at: velocity)
        
        UIView.animate(withDuration: 0.2) {
            self.vc.gradientOverlay.alpha = 0
            self.vc.overlay.alpha = 0
        }
    }
        
    func verticalChange(gesture: UIPanGestureRecognizer) {
        
        let gesturePos = gesture.translation(in: view)
        let adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
            endGesture()
            vc.gradientOverlay.alpha = 0
             vc.resetSizes()
            return
        }
        
        let wouldCommitY = abs(adjustedY) > dismissPointY
        if wouldCommitY != wouldCommitPreviousY {
            feedbackGenerator?.selectionChanged()
            feedbackGenerator?.prepare()
            wouldCommitPreviousY = wouldCommitY
        }
        
        cardView.center.y = view.center.y + adjustedY
        
        self.vc.gradientOverlay.alpha = adjustedY.progress(from: 0, to: 400)

        
        if adjustedY > 0 {
            vc.toolbarHeightConstraint.constant = max(0, Const.toolbarHeight)
        }
        
        let revealProgress = abs(adjustedY) / 200
        
        vc.home.setThumbPosition(
            switcherProgress: adjustedY.progress(from: 0, to: 600),
            cardOffset: CGPoint(
                x: view.center.x - cardView.center.x,
                y: view.center.y - cardView.center.y
            )
        )

        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.radius = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
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
                
                feedbackGenerator = nil
                
                let gesturePos = gesture.translation(in: view)
                var vel = gesture.velocity(in: vc.view)

                let adjustedY : CGFloat = gesturePos.y - startPoint.y
                
                let velIsVertical = abs(vel.y) > abs(vel.x)
                let distIsVertical = abs(gesturePos.y) > abs(gesturePos.x)
                
                if direction == .top && velIsVertical && distIsVertical
                && (vel.y > 600 || adjustedY > dismissPointY) {
                    vel.x = 0
                    commitDismiss(velocity: vel)
                }
                else {
                    vel.x = 0
                    reset(velocity: vel)
                }
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
