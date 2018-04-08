//
//  BrowserGestureController.swift
//  browse
//
//  Created by Evan Brooks on 6/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  We want to capture swipes without interfering with any of
//  the web content. Since we don't know what's in the web
//  content, we just see if any actions bubble out to
//  the elastic scrollview. If they do, we cancel
//  the scroll and begin shifting the cardview ourselves.
//

import UIKit
import pop

enum GestureNavigationDirection {
    case top
    case leftToRight
    case rightToLeft
}
enum GestureNavigationAction {
    case goBack
    case goForward
    case goToParent
}

let DISMISSING = SpringTransitionState.start
let PAGING = SpringTransitionState.end

// Lets us modify scroll position
// from within a scrollviewdidscroll
// delegate without triggering an infinite loop
extension UIScrollView {
    func setScrollSilently(_ offset: CGPoint) {
        let prevDelegate = delegate;
        delegate = nil;
        contentOffset = offset;
        delegate = prevDelegate;
    }
    func setScrollSilently(x newX: CGFloat) {
        var newOffset = contentOffset
        newOffset.x = newX
        setScrollSilently(newOffset)
    }
    func setScrollSilently(y newY: CGFloat) {
        var newOffset = contentOffset
        newOffset.y = newY
        setScrollSilently(newOffset)
    }
}

class BrowserGestureController : NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc : BrowserViewController!

    var view : UIView!
    var toolbar : UIView!
    var cardView : UIView!
    
    var direction : GestureNavigationDirection!
    var dismissVelocity : CGPoint?

    var mockCardView: PlaceholderView!
    let mockCardViewSpacer: CGFloat = 8
    
    var dismissSwitch : SpringSwitch!
    
    var mockPositioner: Blend<CGPoint>!
    var mockScaler: Blend<CGFloat>!
    var mockAlpha:  Blend<CGFloat>!

    var cardPositioner : Blend<CGPoint>!
    var cardScaler : Blend<CGFloat>!
    
    var thumbPositioner : Blend<CGPoint>!

    var isDismissing: Bool = false
    var isDismissingPossible: Bool = false
    var startPoint: CGPoint = .zero
    var startScroll: CGPoint = .zero
    
    let dismissPointX : CGFloat = 150
    let backPointX : CGFloat = 120
    let dismissPointY : CGFloat = 120

    var feedbackGenerator : UISelectionFeedbackGenerator? = nil
    
    var canGoBackToParent : Bool {
        return !vc.webView.canGoBack && vc.currentTab!.hasParent
    }
    
    var switcherRevealProgress : CGFloat {
        return cardView.frame.origin.y.progress(0, 600)
    }
    
    init(for vc : BrowserViewController) {
        super.init()
        
        self.vc = vc
        view = vc.view
        cardView = vc.cardView
        toolbar = vc.toolbar
        
        mockCardView = PlaceholderView(frame: cardView.bounds)
        
        mockPositioner = Blend { self.mockCardView.center = $0 }
        mockScaler = Blend { self.mockCardView.scale = $0  }
        mockAlpha = Blend { self.mockCardView.overlay.alpha = $0  }

        cardPositioner = Blend { self.cardView.center = $0 }
        cardScaler = Blend {
            self.cardView.scale = $0
            self.vc.home.setThumbScale($0)
        }
        thumbPositioner = Blend {
            self.vc.home.setThumbPosition(cardOffset: $0)
        }
        
        dismissSwitch = SpringSwitch {
            self.mockPositioner.progress = $0
            self.mockScaler.progress = $0
            self.mockAlpha.progress = $0
            self.cardPositioner.progress = $0
            self.cardScaler.progress = $0
            self.thumbPositioner.progress = $0
            self.vc.statusBar.label.alpha = $0.reverse().clip()
            self.mockCardView.statusBar.label.alpha = $0.reverse().clip()
            
            self.vc.home.navigationController?.view.alpha = $0.reverse().clip().blend(0.5, 1)
        }
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(anywherePan(gesture:)))
        dismissPanner.cancelsTouchesInView = false
        dismissPanner.delaysTouchesBegan = false
        view.addGestureRecognizer(dismissPanner)
        
        let backDismissPan = UIScreenEdgePanGestureRecognizer()
        backDismissPan.delegate = self
        backDismissPan.edges = .left
        backDismissPan.addTarget(self, action: #selector(leftEdgePan(gesture:)))
        backDismissPan.cancelsTouchesInView = true
        backDismissPan.delaysTouchesBegan = false
        view.addGestureRecognizer(backDismissPan)
        
        let forwardDismissPan = UIScreenEdgePanGestureRecognizer()
        forwardDismissPan.delegate = self
        forwardDismissPan.edges = .right
        forwardDismissPan.addTarget(self, action: #selector(rightEdgePan(gesture:)))
        forwardDismissPan.cancelsTouchesInView = true
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
        && !scrollView.isScrollableY
        && !vc.isShowingToolbar {
            vc.showToolbar(animated: false)
        }
        
        if scrollView.isScrollableY && scrollView.isOverScrolledTop {
            // Cancel, assume gesture will handle
            if !scrollView.isDecelerating {
                scrollView.setScrollSilently(y: 0)
            }
        }
        if !scrollView.isScrollableX
        && (scrollView.isDecelerating || !isDismissingPossible) {
            // For cases that dont trigger an interactivedismiss,
            // but did have horizontal momentum,
            // on a mobile-formatted site that shouldn't allow
            // hscrolling, we want to pretend we haven't set
            // alwaysBouncesHorizontal
            scrollView.setScrollSilently(x: 0)
        }
        
        // if evaluating horizontal overscroll before we've triggered a dismiss,
        // hide anything revealed by shifting mask
        if !scrollView.isScrollableX && isDismissingPossible {
            vc.cardView.mask?.center.x = vc.cardView.center.x + scrollView.contentOffset.x
        }
        
        // Cancel scroll, assume gesture will handle
        if isDismissing && direction == .top {
            scrollView.setScrollSilently(CGPoint(x: startScroll.x, y: 0))
        }
        else if isDismissing && direction == .leftToRight {
            scrollView.setScrollSilently(CGPoint(x: 0, y: startScroll.y))
        }
        else if isDismissing && direction == .rightToLeft {
            scrollView.setScrollSilently(CGPoint(x: scrollView.maxScrollX, y: startScroll.y))
        }
        updateToolbar(scrollView)
    }
    
    func setScrollSilently(_ scrollView: UIScrollView, offset: CGPoint) {
        let prevDelegate = scrollView.delegate;
        scrollView.delegate = nil;
        scrollView.contentOffset = offset;
        scrollView.delegate = prevDelegate;
    }
    
    var shouldUpdateToolbar : Bool {
        let scrollView = vc.webView.scrollView
        return scrollView.isDragging
            && scrollView.isTracking
            && scrollView.isScrollableY
            && !scrollView.isOverScrolledTop
            && !vc.webView.isLoading
    }
    
    func updateToolbar(_ scrollView: UIScrollView) {
        scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y
        
        if self.shouldUpdateToolbar {
            var newH : CGFloat
            if scrollView.isOverScrolledBottomWithInset {
                // Scroll toolbar into view 'naturally' in same direction of scroll
                let amtOver = scrollView.maxScrollY - scrollView.contentOffset.y
                newH = Const.toolbarHeight - amtOver
            } else {
                // Hide on scroll down / show on scroll up
                newH = vc.toolbar.bounds.height - scrollDelta
                if scrollView.contentOffset.y + Const.toolbarHeight > scrollView.maxScrollY {
                    // print("wouldn't be able to hide in time")
                }
            }
            
            let toolbarH = newH.limit(min: 0, max: Const.toolbarHeight)
            
            let pct = toolbarH / Const.toolbarHeight
            
            vc.toolbar.heightConstraint.constant = toolbarH
            
            let inset = -Const.toolbarHeight + toolbarH
            scrollView.contentInset.bottom = inset
            scrollView.scrollIndicatorInsets.bottom = inset
            
            let alpha = pct * 3 - 2
            vc.toolbar.contentsAlpha = alpha
        }
    }
    
    var dragStartScroll : CGFloat = 0
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartScroll = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !scrollView.isOverScrolledTop else { return }

        if scrollView.isOverScrolledBottom || scrollView.contentOffset.y == scrollView.maxScrollYWithInset {
            vc.showToolbar(animated: true, adjustScroll: true)
            return 
        }

        let dragAmount = scrollView.contentOffset.y - dragStartScroll
        
        if      scrollDelta >  1 { vc.hideToolbar() }
        else if scrollDelta < -1 { vc.showToolbar() }
        else if  dragAmount >  1 { vc.hideToolbar() }
        else if  dragAmount < -1 { vc.showToolbar() }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // TODO: Investigate whether this is too expensive, haven't seen problems yet
        vc.updateSnapshot()
    }
    
    let vProgressScaleMultiplier : CGFloat = 0
    let vProgressCancelBackScaleMultiplier : CGFloat = 0.2
    let cantGoBackScaleMultiplier : CGFloat = 1.2
    let backBeginScale: CGFloat = 0.97
    
    var wouldCommitPreviousX = false
    var wouldCommitPreviousY = false

    func horizontalChange(_ gesture: UIPanGestureRecognizer) {
        guard isDismissing && (direction == .leftToRight || direction == .rightToLeft) else { return }
        
        let gesturePos = gesture.translation(in: view)
        
        let revealProgress = min(abs(gesturePos.x) / 200, 1)
        
        let rad = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.radius = rad
            mockCardView.radius = rad
        }

        let adjustedX = gesturePos.x - startPoint.x
        let yGestureInfluence = gesturePos.y

        let verticalProgress = gesturePos.y.progress(0, 200).clip()
        
//        let sign : CGFloat = adjustedX > 0 ? 1 : -1 //direction == .left ? 1 : -1
        let sign : CGFloat = direction == .leftToRight ? 1 : -1
        let hProg = elasticLimit(abs(adjustedX)) / view.bounds.width //* sign
        let dismissScale = (1 - hProg * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier)//.clip()
        let hintScale = yGestureInfluence.progress(0, 160).clip().blend(1, 0.7)
        let backScale = adjustedX.progress(0, 400).blend(backBeginScale, 1)

        let spaceW = cardView.bounds.width * ( 1 - dismissScale )
        let spaceH = cardView.bounds.height * ( 1 - dismissScale )

        cardScaler.setValue(of: PAGING, to: 1)
        cardScaler.setValue(of: DISMISSING, to: dismissScale)
        mockScaler.setValue(of: DISMISSING, to: dismissScale)

        let isToParent = direction == .leftToRight && !vc.webView.canGoBack && canGoBackToParent
        let cantPage = (direction == .leftToRight && !vc.webView.canGoBack && !isToParent)
                    || (direction == .rightToLeft && !vc.webView.canGoForward)
        
        var dismissingPoint = CGPoint(
            x: view.center.x + spaceW * 0.4 * sign,
            y: view.center.y + max(elasticLimit(yGestureInfluence), yGestureInfluence) - spaceH * (0.5 - startAnchorOffsetPct)
        )
        mockPositioner.setValue(of: DISMISSING, to: CGPoint(
            x: view.center.x - view.bounds.width * sign,
            y: view.center.y))
        
        let backFwdPoint = CGPoint(
            x: view.center.x + adjustedX,
            y: view.center.y + 0.5 * max(0, yGestureInfluence))
        
        let thumbAlpha = switcherRevealProgress.progress(0, 0.7).clip().blend(0, 1)
//        vc.home.navigationController?.view.alpha = thumbAlpha

        cardScaler.setValue(of: PAGING, to: hintScale)
        let hintX = yGestureInfluence.progress(0, 160).clip().blend(0, 120)

        // reveal back page from left
        if (direction == .leftToRight && vc.webView.canGoBack) || isToParent {
            dismissingPoint.y -= dismissPointY * 0.5 // to account for initial resisitance
            let parallax : CGFloat = 0.5
            cardPositioner.setValue(of: PAGING, to: backFwdPoint)
            mockAlpha.setValue(of: PAGING, to: adjustedX.progress(0, 400).blend(0.4, 0.1))
            
            if isToParent && false {
                mockPositioner.setValue(of: PAGING, to: CGPoint(
                    x: view.center.x + adjustedX * 0.2 - view.bounds.width * 0.2,
                    y: view.center.y + 0.2 * min(0, -yGestureInfluence) ))
                mockScaler.setValue(of: PAGING, to: yGestureInfluence.progress(0, dismissPointY).clip().blend(backScale, 0.8))
                mockAlpha.setValue(of: DISMISSING, to: thumbAlpha.reverse())
                mockPositioner.setValue(of: DISMISSING, to: CGPoint(
                    x: dismissingPoint.x,
                    y: dismissingPoint.y - dismissScale * view.bounds.height - 12 ))
            }
            else {
                mockScaler.setValue(of: PAGING, to: backScale * hintScale )
                mockPositioner.setValue(of: PAGING, to: CGPoint(
                    x: view.center.x + adjustedX * parallax - view.bounds.width * parallax * hintScale + hintX,
                    y: backFwdPoint.y ))
                mockScaler.setValue(of: DISMISSING, to: dismissScale * backBeginScale)
                mockAlpha.setValue(of: DISMISSING, to: 0.7)
                mockPositioner.setValue(of: DISMISSING, to: dismissingPoint)
            }
        }
        // overlay forward page from right
        else if direction == .rightToLeft && vc.webView.canGoForward {
            dismissingPoint.y -= dismissPointY * 0.5 // to account for initial resisitance
            cardPositioner.setValue(of: PAGING, to: CGPoint(
                x: view.center.x + adjustedX * 0.8 + hintX * 0.5,
                y: backFwdPoint.y ))
            let isBackness = adjustedX.progress(0, -400) * gesturePos.y.progress(100, 160).clip().reverse()
            vc.overlay.alpha = isBackness.blend(0, 0.4)
            
            let pageScale = adjustedX.progress(0, -400).blend(1, 0.95)
            cardScaler.setValue(of: PAGING, to: pageScale * hintScale)
            
            let hintX = yGestureInfluence.progress(0, 160).clip().blend(0, 120)

            mockAlpha.setValue(of: PAGING, to: 0)
            mockScaler.setValue(of: PAGING, to: 1)
            mockScaler.setValue(of: DISMISSING, to: 1)
            mockPositioner.setValue(of: PAGING, to: CGPoint(
                x: view.center.x + adjustedX * 1.2 + view.bounds.width + hintX,
                y: view.center.y ))
        }
        // rubber band
        else if cantPage {
            cardPositioner.setValue(of: PAGING, to: CGPoint(
                x: view.center.x + elasticLimit(adjustedX, constant: 100),
                y: backFwdPoint.y ))
            thumbPositioner.setValue(of: PAGING, to: CGPoint(
                x: -elasticLimit(adjustedX, constant: 100),
                y: 0 ))
        }

        cardPositioner.setValue(of: DISMISSING, to: dismissingPoint)
        thumbPositioner.setValue(of: DISMISSING, to: CGPoint(
            x: view.center.x - dismissingPoint.x,
            y: view.center.y - dismissingPoint.y
        ))
        thumbPositioner.setValue(of: PAGING, to: CGPoint(
            x: 0,
            y: view.center.y - backFwdPoint.y
        ))

        
        let isVerticalDismiss = gesturePos.y > dismissPointY
        let isHorizontalDismiss = false //abs(adjustedX) > 80
        let newState = (isVerticalDismiss || (cantPage && isHorizontalDismiss)) ? DISMISSING : PAGING
        dismissSwitch.springState(newState)

        updateStatusBar()
    }
    
    func endGesture() {
        isDismissing = false
    }

    func verticalEnd(_ gesture: UIPanGestureRecognizer) {
        if !isDismissing { return }
        endGesture()
        
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
    
    func horizontalEnd(_ gesture: UIPanGestureRecognizer) {
        if !isDismissing { return }
        endGesture()

        let gesturePos = gesture.translation(in: view)
        let adjustedX = gesturePos.x - startPoint.x
        let vel = gesture.velocity(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
        
        if (direction == .leftToRight || direction == .rightToLeft)
        && gesturePos.y > dismissPointY  {
            commitDismiss(velocity: vel)
        }
        else if adjustedX > backPointX && isHorizontal{
            if vc.webView.canGoBack
            && mockCardView.frame.origin.x + mockCardView.frame.width > backPointX {
                vc.webView.goBack()
                animateCommit(action: .goBack, velocity: vel)
                vc.hideUntilNavigationDone()
            }
            else if canGoBackToParent
            && adjustedX > backPointX {
                if let parentTab = vc.currentTab?.parentTab {
                    vc.updateSnapshot {
                        let vc = self.vc!
                        self.mockCardView.imageView.image = vc.currentTab?.currentItem?.snapshot
                        vc.setTab(parentTab)
                        self.animateCommit(action: .goToParent)
                        vc.home.moveTabToEnd(parentTab)
                    }
                }
            }
            else {
//                commitDismiss(velocity: vel)
                reset(velocity: vel)
            }
        }
        else if adjustedX < -backPointX && isHorizontal {
            if vc.webView.canGoForward {
                print("Could go forward to one of the following")
                let _ = vc.currentTab?.currentItem?.forwardItems?.allObjects.map({ item in
                    if let item = item as? HistoryItem {
                        print("- \(item.title ?? "No Title")")
                    }
                })
                vc.webView.goForward()
                animateCommit(action: .goForward, velocity: vel)
                vc.hideUntilNavigationDone()
            }
            else {
//                commitDismiss(velocity: vel)
                reset(velocity: vel)
            }
        }
        else {
            reset(velocity: vel)
        }
    }
    
    func resetMockCardView() {
        mockCardView.transform = .identity
        mockCardView.center = vc.view.center
        mockCardView.center.x += cardView.bounds.width
        mockCardView.bounds = cardView.bounds
    }
    
    @objc
    func leftEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            startGesture(gesture, direction: .leftToRight)
            startPoint = .zero
            vc.showToolbar()
        }
        else if gesture.state == .changed { horizontalChange(gesture) }
        else if gesture.state == .ended { horizontalEnd(gesture) }
    }
    
    @objc
    func rightEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            startGesture(gesture, direction: .rightToLeft)
            startPoint = .zero
            vc.showToolbar()
        }
        else if gesture.state == .changed { horizontalChange(gesture) }
        else if gesture.state == .ended { horizontalEnd(gesture) }
    }

    func setupBackGesture() {
        resetMockCardView()
        guard let backItem = vc.webView.backForwardList.backItem?.model else { return }
        mockCardView.setPage(backItem)
        view.addSubview(mockCardView)
        view.bringSubview(toFront: cardView)
    }
    
    func setupForwardGesture() {
        resetMockCardView()
        guard let fwdItem = vc.webView.backForwardList.forwardItem?.model else { return }
        mockCardView.setPage(fwdItem)
        view.addSubview(mockCardView)
    }
    
    func setupBackToParentGesture() {
        guard let parent = vc.currentTab?.parentTab,
            let parentPage = parent.currentItem else { return }
        view.insertSubview(mockCardView, belowSubview: cardView)
        mockCardView.setPage(parentPage)
        vc.home.setParentHidden(parent, hidden: true)
    }
    
    func considerStarting(gesture: UIPanGestureRecognizer) {
        let scrollView = vc.webView.scrollView
        let scroll = scrollView.contentOffset
        if scrollView.isZooming || scrollView.isZoomBouncing { return }
        
        let gestureVel = gesture.velocity(in: view)
        let gesturePos = gesture.translation(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
        let hasHorizontalVel = abs(gestureVel.x) > 500
        
        // Consider starting vertical dismiss
        if scrollView.isScrollableY && scroll.y <= 0 && gesturePos.y > 0 {
            // Body scrollable, cancel at scrollPos 0
            startGesture(gesture, direction: .top)
        }
        else if !scrollView.isScrollableY && scroll.y < 0 && gesturePos.y > 0 {
            // Inner div is scrollable, trigger at scrollPos -1
            startGesture(gesture, direction: .top)
        }
            
        // Consider horizontal dismiss
        else if scrollView.isScrollableX && isHorizontal && hasHorizontalVel {
            // Body hScrollable
            if scroll.x <= 0 && gesturePos.x > 0 {
                startGesture(gesture, direction: .leftToRight)
            }
            else if scroll.x >= scrollView.maxScrollX && gesturePos.x < 0 {
                startGesture(gesture, direction: .rightToLeft)
            }
        }
        else if !scrollView.isScrollableX && isHorizontal && hasHorizontalVel {
            // Inner div is hscrollable, trigger at scrollPos -1
            if scroll.x < 0 && gesturePos.x > 0 {
                startGesture(gesture, direction: .leftToRight)
            }
            else if scroll.x > scrollView.maxScrollX && gesturePos.x < 0 {
                startGesture(gesture, direction: .rightToLeft)
            }
        }
        
        // Definitely cancel
        else if abs(gesturePos.x) > 10 {
            dismissingEndedPossible()
        }
    }
    
    
    var startAnchorOffsetPct: CGFloat = 0
    
    func startGesture(_ gesture: UIPanGestureRecognizer, direction newDir: GestureNavigationDirection) {
        isDismissing = true
        dismissingEndedPossible()
        direction = newDir
        startPoint = gesture.translation(in: view)
        
        startAnchorOffsetPct = gesture.location(in: view).y / view.bounds.height
        
        startScroll = vc.webView.scrollView.contentOffset
        vc.webView.scrollView.showsVerticalScrollIndicator = false
        vc.webView.scrollView.cancelScroll()
        
        vc.currentTab?.updateSnapshot(from: vc.webView)
        vc.contentView.radius = Const.shared.cardRadius
        
        if direction == .leftToRight {
            if vc.webView.canGoBack { setupBackGesture() }
            else { setupBackToParentGesture() }
        }
        else if direction == .rightToLeft {
            if vc.webView.canGoForward { setupForwardGesture() }
        }
        if direction != .top {
            dismissSwitch.setState(PAGING)
            horizontalChange(gesture)
        }
    }
    
    func commitDismiss(velocity vel: CGPoint) {
        
        dismissVelocity = vel
        dismissSwitch.cancel()
        if let parent = vc.currentTab?.parentTab {
            vc.home.setParentHidden(parent, hidden: false)
        }
        mockCardView.removeFromSuperview()
        mockCardView.imageView.image = nil
        
        vc.dismiss(animated: true) {
            self.dismissVelocity = nil
        }
    }
    
    func swapTo(childTab: Tab) {
        let parentMock = cardView.snapshotView(afterScreenUpdates: false)!
        parentMock.contentMode = .top
        parentMock.clipsToBounds = true
        parentMock.radius = Const.shared.cardRadius
        
        vc.view.insertSubview(parentMock, belowSubview: cardView)
        vc.contentView.radius = Const.shared.cardRadius

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
                vc.contentView.radius = 0
                vc.home.moveTabToEnd(childTab)
            })
        }
    }
    
    func swapTo(parentTab: Tab) {
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
        if action != .goToParent {
            mockCardView.imageView.image = vc.currentTab?.currentItem?.snapshot
        }
        
        // Swap colors
        let statusColor = vc.statusBar.backgroundColor
        let toolbarColor = vc.toolbar.backgroundColor
        vc.statusBar.backgroundColor = mockCardView.statusBar.backgroundColor
        vc.toolbar.backgroundColor = mockCardView.toolbarView.backgroundColor
        vc.statusBar.backgroundView.alpha = 1
        vc.toolbar.backgroundView.alpha = 1
        mockCardView.statusBar.backgroundColor = statusColor
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
        if action == .goToParent || action == .goBack {
            view.insertSubview(mockCardView, aboveSubview: cardView)
        } else {
            view.insertSubview(mockCardView, belowSubview: cardView)
        }
    }

    func animateCommit(action: GestureNavigationAction, velocity: CGPoint = .zero) {
        dismissSwitch.cancel()
        swapCardAndPlaceholder(for: action)

        var adjustedVel = velocity
        adjustedVel.y = 0
        
        mockPositioner.end = self.view.center
        let mockShift = mockCardView.bounds.width
        if action == .goBack || action == .goToParent {
            mockPositioner.end.x += mockShift
        }
        else if action == .goForward {
            mockPositioner.end.x -= mockShift / 2
        }

        // dont use velocity for this part, since it
        // wasn't directly tracking gesture
        cardView.springCenter(to: view.center, at: adjustedVel) {_,_ in
            self.vc.resetSizes()
            self.vc.view.bringSubview(toFront: self.cardView)
            self.vc.contentView.radius = 0

            UIView.animate(withDuration: 0.2, animations: {
                self.vc.home.setNeedsStatusBarAppearanceUpdate()
            })
            if action == .goToParent {
                self.vc.isSnapshotMode = false
            }
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
        }
        
        mockCardView.springCenter(to: mockPositioner.end, at: adjustedVel) {_,_ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        mockCardView.springScale(to: 1)
        cardView.springScale(to: 1)
        
        UIView.animate(withDuration: 0.3) {
            self.vc.overlay.alpha = 0
        }
    }

    func reset(velocity: CGPoint) {
        dismissSwitch.cancel()
        vc.webView.scrollView.cancelScroll()

        var hVel = velocity
        hVel.y = 0

        // Move card back to center
        cardView.springCenter(to: view.center, at: velocity) {_,_ in
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.home.setNeedsStatusBarAppearanceUpdate()
            })
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
            self.vc.contentView.radius = 0
        }
        cardView.springScale(to: 1)

        var mockCenter = self.view.center
        let mockShift = mockCardView.bounds.width
        if mockCardView.center.x > view.center.x {
            mockCenter.x += mockShift
        }
        else {
            mockCenter.x -= mockShift / 2
        }
        
        /* don't use velocity for this */
        mockCardView.springCenter(to: mockCenter, at: hVel) {_,_ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        mockCardView.springScale(to: 1)
//        vc.statusHeightConstraint.springConstant(to: Const.statusHeight)
        vc.home.springCards(toStacked: false, at: velocity)
        vc.home.setThumbsVisible()
        
        UIView.animate(withDuration: 0.2) {
            self.vc.overlay.alpha = 0
            self.vc.statusBar.label.alpha = 0
        }
    }
        
    func verticalChange(gesture: UIPanGestureRecognizer) {
        let gesturePos = gesture.translation(in: view)
        let adjustedY : CGFloat = gesturePos.y - startPoint.y
        
        if (direction == .top && adjustedY < 0) {
            endGesture()
             vc.resetSizes()
            return
        }
        
        if adjustedY > 0 {
            vc.toolbar.heightConstraint.constant = max(0, Const.toolbarHeight)
        }
        
        let revealProgress = abs(adjustedY) / 200
        let dismissScale = 1 - adjustedY.progress(0, 600).clip() * 0.5 * abs(gesturePos.x).progress(0, 200)
        
        let spaceW = cardView.bounds.width * ( 1 - dismissScale )
        
        cardScaler.setValue(of: PAGING, to: 1)
        cardScaler.setValue(of: DISMISSING, to: dismissScale)
        
        let extraH = cardView.bounds.height * (1 - dismissScale) * 0.5
        
        cardPositioner.setValue(of: DISMISSING, to: CGPoint(
            x: view.center.x + gesturePos.x.progress(0, 500) * spaceW,
            y: view.center.y + adjustedY - extraH
        ))
        thumbPositioner.setValue(of: DISMISSING, to: CGPoint(
            x: view.center.x - cardView.center.x,
            y: view.center.y - cardView.center.y
        ))
//        let thumbAlpha = switcherRevealProgress.progress(from: 0, to: 0.7).blend(from: 0.2, to: 1)
//        vc.home.navigationController?.view.alpha = thumbAlpha

        dismissSwitch.setState(DISMISSING)
        
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.radius = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        }
        
        updateStatusBar()
    }
    
    func updateStatusBar() {
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle
        || vc.prefersStatusBarHidden != UIApplication.shared.isStatusBarHidden {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func dismissingEndedPossible() {
        vc.cardView.mask = nil
        isDismissingPossible = false
    }
    
    func dismissingBecamePossible() {
        let mask = UIView()
        mask.backgroundColor = .red
        mask.frame = vc.cardView.bounds
        vc.cardView.mask = mask
        isDismissingPossible = true
    }
    
    @objc func anywherePan(gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            dismissingBecamePossible()
            considerStarting(gesture: gesture)
        }
        else if gesture.state == .changed {
            if isDismissing {
                if direction == .top { verticalChange(gesture: gesture) }
                else { horizontalChange(gesture) }
            }
            else if isDismissingPossible {
                considerStarting(gesture: gesture)
            }
        }
        else if gesture.state == .ended {
            if isDismissing {
                if direction == .top { verticalEnd(gesture) }
                else { horizontalEnd(gesture) }
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // TODO: Want to recognize swipe with scroll,
        // but not edgeswipe and real swipe at same time
        return true
    }
}
