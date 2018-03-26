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
    case bottom
    case left
    case right
}
enum GestureNavigationAction {
    case goBack
    case goForward
    case goToParent
}

let DISMISSING = SpringTransitionState.start
let PAGING = SpringTransitionState.end

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

    var isInteractiveDismiss : Bool = false
    var startPoint : CGPoint = .zero
    var startScroll : CGPoint = .zero
    
    let dismissPointX : CGFloat = 150
    let backPointX : CGFloat = 120
    let dismissPointY : CGFloat = 120

    var feedbackGenerator : UISelectionFeedbackGenerator? = nil
    
    var canGoBackToParent : Bool {
        return !vc.webView.canGoBack && vc.currentTab!.hasParent
    }
    
    var switcherRevealProgress : CGFloat {
        return cardView.frame.origin.y.progress(from: 0, to: 600)
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
                scrollView.contentOffset.y = 0
            }
        }
        if !scrollView.isScrollableX && scrollView.isDecelerating {
            // For cases that dont trigger an interactivedismiss,
            // but did have horizontal momentum,
            // on a mobile-formatted site that shouldn't allow
            // hscrolling, we want to pretend we haven't set
            // alwaysBouncesHorizontal
            scrollView.contentOffset.x = 0
        }
        
        // Cancel scroll, assume gesture will handle
        if isInteractiveDismiss && direction == .top {
            scrollView.contentOffset.y = 0
            scrollView.contentOffset.x = startScroll.x
        }
        else if isInteractiveDismiss && direction == .left {
            scrollView.contentOffset.x = 0
            scrollView.contentOffset.y = startScroll.y
        }
        else if isInteractiveDismiss && direction == .right {
            scrollView.contentOffset.x = scrollView.maxScrollX
            scrollView.contentOffset.y = startScroll.y
        }
        
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
    
    var shouldUpdateToolbar : Bool {
        let scrollView = vc.webView.scrollView
        return scrollView.isDragging
            && scrollView.isTracking
            && scrollView.isScrollableY
            && !scrollView.isOverScrolledTop
            && !vc.webView.isLoading
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
    
    var wouldCommitPreviousX = false
    var wouldCommitPreviousY = false

    func horizontalChange(_ gesture: UIPanGestureRecognizer) {
        guard isInteractiveDismiss && (direction == .left || direction == .right) else { return }
        
        let gesturePos = gesture.translation(in: view)
        
        let revealProgress = min(abs(gesturePos.x) / 200, 1)
        
        let rad = min(Const.shared.cardRadius + revealProgress * 4 * Const.shared.thumbRadius, Const.shared.thumbRadius)
        if (Const.shared.cardRadius < Const.shared.thumbRadius) {
            cardView.radius = rad
            mockCardView.radius = rad
        }

        let adjustedX = gesturePos.x - startPoint.x
        let yGestureInfluence = gesturePos.y

        let verticalProgress = gesturePos.y.progress(from: 0, to: 200).clip()
        
        let sign : CGFloat = adjustedX > 0 ? 1 : -1 //direction == .left ? 1 : -1
        let hProg = elasticLimit(abs(adjustedX)) / view.bounds.width //* sign
        let dismissScale = (1 - hProg * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier)//.clip()
        let spaceW = cardView.bounds.width * ( 1 - dismissScale )
        let spaceH = cardView.bounds.height * ( 1 - dismissScale )

        cardScaler.setValue(of: PAGING, to: 1)
        cardScaler.setValue(of: DISMISSING, to: dismissScale)
        mockScaler.setValue(of: DISMISSING, to: dismissScale)
        thumbPositioner.setValue(of: PAGING, to: .zero)

        let isToParent = direction == .left && !vc.webView.canGoBack && canGoBackToParent
        let cantPage = (direction == .left && !vc.webView.canGoBack && !isToParent)
                    || (direction == .right && !vc.webView.canGoForward)
        
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
        
        let thumbAlpha = switcherRevealProgress.progress(from: 0, to: 0.7).clip().blend(from: 0, to: 1)
//        vc.home.navigationController?.view.alpha = thumbAlpha

        // reveal back page from left
        if (direction == .left && vc.webView.canGoBack) || isToParent {
            dismissingPoint.y -= dismissPointY * 0.5 // to account for initial resisitance
            let parallax : CGFloat = 0.5
            cardPositioner.setValue(of: PAGING, to: backFwdPoint)
            mockPositioner.setValue(of: PAGING, to: CGPoint(
                    x: view.center.x + adjustedX * parallax - view.bounds.width * parallax,
                    y: backFwdPoint.y ))
            if isToParent {
                mockAlpha.setValue(of: DISMISSING, to: thumbAlpha.reverse())
                mockPositioner.setValue(of: DISMISSING, to: CGPoint(
                    // TODO: keep x and y positions in sync with
                    // how tabswitcher is calculating it
                    x: view.center.x + (dismissingPoint.x - view.center.x) * 0.9,
                    y: dismissingPoint.y - 160 * switcherRevealProgress ))
            }
            else {
//                mockPositioner.setValue(of: DISMISSING, to: dismissingPoint)
                mockScaler.setValue(of: DISMISSING, to: 1)
//                mockAlpha.setValue(of: DISMISSING, to: 1)
                mockAlpha.setValue(of: DISMISSING, to: 1)
                mockPositioner.setValue(of: DISMISSING, to: CGPoint(
                    x: view.center.x - vc.cardView.bounds.width,
                    y: backFwdPoint.y ))
            }
            mockAlpha.setValue(of: PAGING, to: adjustedX.progress(from: 0, to: 400).blend(from: 0.4, to: 0.1))
            mockScaler.setValue(of: PAGING, to: 1)
        }
        // overlay forward page from right
        else if direction == .right && vc.webView.canGoForward {
            dismissingPoint.y -= dismissPointY * 0.5 // to account for initial resisitance
            cardPositioner.setValue(of: PAGING, to: CGPoint(
                x: view.center.x + adjustedX * 0.5,
                y: backFwdPoint.y ))
            let isBackness = adjustedX.progress(from: 0, to: -400) * gesturePos.y.progress(from: 100, to: 160).clip().reverse()
            vc.overlay.alpha = isBackness.blend(from: 0, to: 0.4)
            mockAlpha.setValue(of: PAGING, to: 0)
            mockScaler.setValue(of: DISMISSING, to: 1)
            mockPositioner.setValue(of: PAGING, to: CGPoint(
                x: backFwdPoint.x + view.bounds.width,
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
        
        
        let isVerticalDismiss = gesturePos.y > dismissPointY
        let isHorizontalDismiss = false //abs(adjustedX) > 80
        let newState = (isVerticalDismiss || (cantPage && isHorizontalDismiss)) ? DISMISSING : PAGING
        dismissSwitch.springState(newState)

        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func endGesture() {
        isInteractiveDismiss = false
    }

    func verticalEnd(_ gesture: UIPanGestureRecognizer) {
        if !isInteractiveDismiss { return }
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
        if !isInteractiveDismiss { return }
        endGesture()

        let gesturePos = gesture.translation(in: view)
        let adjustedX = gesturePos.x - startPoint.x
        let vel = gesture.velocity(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
        
        if (direction == .left || direction == .right)
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
                let items = vc.currentTab?.currentItem?.forwardItems?.allObjects.map({ item in
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
            startGesture(gesture, direction: .left)
            startPoint = .zero
            vc.showToolbar()
        }
        else if gesture.state == .changed { horizontalChange(gesture) }
        else if gesture.state == .ended { horizontalEnd(gesture) }
    }
    
    @objc
    func rightEdgePan(gesture:UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            startGesture(gesture, direction: .right)
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
        
        let gesturePos = gesture.translation(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
        
        // Consider starting vertical dismiss
        if scrollView.isScrollableY && scroll.y == 0 && gesturePos.y > 0 {
            // Body scrollable, cancel at scrollPos 0
            startGesture(gesture, direction: .top)
        }
        else if !scrollView.isScrollableY && scroll.y < 0 && gesturePos.y > 0 {
            // Inner div is scrollable, trigger at scrollPos -1
            startGesture(gesture, direction: .top)
        }
        // Consider horizontal dismiss
        else if scrollView.isScrollableX && isHorizontal {
            // Body hScrollable
            if scroll.x <= 0 && gesturePos.x > 0 {
                startGesture(gesture, direction: .left)
            }
            else if scroll.x >= scrollView.maxScrollX && gesturePos.x < 0 {
                startGesture(gesture, direction: .right)
            }
        }
        else if !scrollView.isScrollableX && isHorizontal {
            // Inner div is hscrollable, trigger at scrollPos -1
            if scroll.x < 0 && gesturePos.x > 0 {
                startGesture(gesture, direction: .left)
            }
            else if scroll.x > scrollView.maxScrollX && gesturePos.x < 0 {
                startGesture(gesture, direction: .right)
            }
        }

    }
    
    
    var shouldRestoreKeyboard: Bool = false
    var startAnchorOffsetPct: CGFloat = 0
    
    func startGesture(_ gesture: UIPanGestureRecognizer, direction newDir: GestureNavigationDirection) {
        isInteractiveDismiss = true
        direction = newDir
        startPoint = gesture.translation(in: view)
        
        startAnchorOffsetPct = gesture.location(in: view).y / view.bounds.height
        
        startScroll = vc.webView.scrollView.contentOffset
        vc.webView.scrollView.showsVerticalScrollIndicator = false
        vc.webView.scrollView.cancelScroll()
        
        vc.currentTab?.updateSnapshot(from: vc.webView)
        vc.contentView.radius = Const.shared.cardRadius

        if direction == .left {
            if vc.webView.canGoBack { setupBackGesture() }
            else { setupBackToParentGesture() }
        }
        else if direction == .right {
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
        
        vc.home.navigationController?.view.alpha = 0 // TODO not here
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
        let statusColor = vc.statusBar.lastColor
        let toolbarColor = vc.toolbar.lastColor
        vc.statusBar.setBackground(to: mockCardView.statusBar.lastColor ?? .white)
        vc.toolbar.setBackground(to: mockCardView.toolbarView.backgroundColor ?? .white)
        vc.statusBar.backgroundView.alpha = 1
        vc.toolbar.backgroundView.alpha = 1
        mockCardView.statusBar.setBackground(to: statusColor)
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
        
        if (direction == .top && adjustedY < 0) || (direction == .bottom && adjustedY > 0) {
            endGesture()
             vc.resetSizes()
            return
        }
        
        if adjustedY > 0 {
            vc.toolbarHeightConstraint.constant = max(0, Const.toolbarHeight)
        }
        
        let revealProgress = abs(adjustedY) / 200
        let dismissScale = 1 - adjustedY.progress(from: 0, to: 600).clip() * 0.5 * abs(gesturePos.x).progress(from: 0, to: 200)
        
        let spaceW = cardView.bounds.width * ( 1 - dismissScale )
        
        cardScaler.setValue(of: PAGING, to: 1)
        cardScaler.setValue(of: DISMISSING, to: dismissScale)
        
        let extraH = cardView.bounds.height * (1 - dismissScale) * 0.5
        
        cardPositioner.setValue(of: DISMISSING, to: CGPoint(
            x: view.center.x + gesturePos.x.progress(from: 0, to: 500) * spaceW,
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
        
        
        if vc.preferredStatusBarStyle != UIApplication.shared.statusBarStyle {
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
    }
    
    
    @objc func anywherePan(gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            considerStarting(gesture: gesture)
        }
        else if gesture.state == .changed {
            if isInteractiveDismiss {
                if direction == .top { verticalChange(gesture: gesture) }
                else { horizontalChange(gesture) }
            }
            else if !isInteractiveDismiss {
                considerStarting(gesture: gesture)
            }
        }
        else if gesture.state == .ended {
            if isInteractiveDismiss {
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
