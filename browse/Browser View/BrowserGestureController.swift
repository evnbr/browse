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

extension Blend {
    var dismissState: T {
        get {
            return self.start
        }
        set {
            self.setValue(of: .start, to: newValue)
        }
    }
    var pagingState: T {
        get {
            return self.end
        }
        set {
            self.setValue(of: .end, to: newValue)
        }
    }
}

let GESTURE_DEBUG = false
// Lets us modify scroll position
// from within a scrollviewdidscroll
// delegate without triggering an infinite loop
extension UIScrollView {
    func setScrollSilently(_ offset: CGPoint) {
        let prevDelegate = delegate
        delegate = nil
        contentOffset = offset
        delegate = prevDelegate
    }
    func safeY(_ newY: CGFloat) -> CGFloat {
        return max(0, min(newY, self.maxScrollY))
    }
    func safeX(_ newX: CGFloat) -> CGFloat {
        return max(0, min(newX, self.maxScrollX))
    }
    func setScrollSilently(x newX: CGFloat) {
        var newOffset = contentOffset
        newOffset.x = safeX(newX)
        setScrollSilently(newOffset)
    }
    func setScrollSilently(y newY: CGFloat) {
        var newOffset = contentOffset
        newOffset.y = safeY(newY)
        setScrollSilently(newOffset)
    }
}

// swiftlint:disable:next type_body_length
class BrowserGestureController: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    var vc: BrowserViewController!

    var view: UIView!
    var toolbar: UIView!
    var cardView: UIView!

    let pinchController = BrowserPinchController()

    var direction: GestureNavigationDirection!
    var dismissVelocity: CGPoint?

    var mockCardView: PlaceholderView!
    let mockCardViewSpacer: CGFloat = 8

    var dismissSwitch: SpringSwitch!

    var cardPositioner: Blend<CGPoint>!
    var cardScaler: Blend<CGFloat>!

    var thumbPositioner: Blend<CGPoint>!
    var thumbScaler: Blend<CGFloat>!

    var isDismissing: Bool = false
    var isDismissingPossible: Bool = false
    var startPoint: CGPoint = .zero
    var startScroll: CGPoint = .zero

    let dismissPointX: CGFloat = 150
    let backPointX: CGFloat = 120
    let dismissPointY: CGFloat = 120 //  120
    let dismissPointPreviewY: CGFloat = 200 //  120

    var feedbackGenerator: UISelectionFeedbackGenerator?

    var canGoBackToParent: Bool {
//        guard let backVisit = vc.currentTab.currentVisit?.backItem,
//            let backTab = backVisit.tab,
//            backTab !== vc.currentTab,
//            backTab.currentVisit == backVisit else { return false }
//        return true
        return !vc.webView.canGoBack && vc.currentTab.parentTab != nil
    }

    var switcherRevealProgress: CGFloat {
        return cardView.frame.origin.y.progress(0, 600)
    }

    init(for vc: BrowserViewController) {
        super.init()

        self.vc = vc
        pinchController.vc = vc
        view = vc.view
        cardView = vc.cardView
        toolbar = vc.toolbar

        mockCardView = PlaceholderView(frame: cardView.bounds)

        cardPositioner = Blend { self.cardView.center = $0 }
        cardScaler = Blend {
            self.cardView.scale = $0
        }
        thumbScaler = Blend {
            self.vc.tabSwitcher.setThumbScale($0)
        }
        thumbPositioner = Blend {
            self.vc.tabSwitcher.updateStackOffset(for: $0)
        }
        dismissSwitch = SpringSwitch {
            self.mockCardView.positioner.progress = $0
            self.mockCardView.scaler.progress = $0
            self.mockCardView.darkener.progress = $0
            self.cardPositioner.progress = $0
            self.cardScaler.progress = $0
            self.thumbScaler.progress = $0
            self.thumbPositioner.progress = $0
            self.vc.statusBar.label.alpha = $0.reverse().clip()
            self.mockCardView.statusBar.label.alpha = $0.reverse().clip()
        }

        setupGestures()
    }

    func setupGestures() {
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(anywherePan(gesture:)))
        dismissPanner.cancelsTouchesInView = false
        dismissPanner.delaysTouchesBegan = false
        vc.contentView.addGestureRecognizer(dismissPanner)

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

        let pincher = UIPinchGestureRecognizer()
        pincher.delegate = self
        pincher.addTarget(pinchController, action: #selector(pinchController.pinch(gesture:)))
        vc.contentView.addGestureRecognizer(pincher)
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        vc.showToolbar()
    }
    var prevScrollY: CGFloat = 0
    var scrollDelta: CGFloat = 0
    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        // Cancel Y, assume gesture will handle
        if scrollView.isScrollableY && scrollView.isOverScrolledTop && isDismissing {
            if !scrollView.isDecelerating {
                scrollView.setScrollSilently(y: 0)
            }
        }

        // Cancel X, assume gesture will handle
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
            vc.cardView.mask?.center.x = vc.cardView.center.x - scrollView.contentOffset.x
        }

        // Cancel scroll, assume gesture will handle
        if isDismissing && direction == .top {
            scrollView.setScrollSilently(CGPoint(x: startScroll.x, y: 0))
        } else if isDismissing && direction == .leftToRight {
            scrollView.setScrollSilently(x: 0)
        } else if isDismissing && direction == .rightToLeft {
            scrollView.setScrollSilently(x: scrollView.maxScrollX)
        } else if pinchController.isPinchDismissing {
            scrollView.setScrollSilently(pinchController.pinchStartScroll)
        }
        updateToolbar(scrollView)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if pinchController.isPinchDismissing {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
    }

    var shouldUpdateToolbar: Bool {
        let scrollView = vc.webView.scrollView
        return scrollView.isDragging
            && scrollView.isTracking
            && scrollView.isScrollableY
            && !scrollView.isOverScrolledTop
            && !vc.webView.isLoading
            && !pinchController.isPinchDismissing
            && !isDismissing
            && !vc.isDisplayingSearch
//            && !vc.searchVC.isTransitioning
//            && !vc.searchVC.isSwiping
    }

    func updateToolbar(_ scrollView: UIScrollView) {
        // Navigated to page that is not scrollable
        if scrollView.contentOffset.y == 0 && !scrollView.isScrollableY && !vc.isShowingToolbar {
            vc.showToolbar(animated: false)
            return
        }
        if vc.isDisplayingSearch {
            scrollDelta = 0
            prevScrollY = scrollView.contentOffset.y
            if !vc.isShowingToolbar { vc.showToolbar(animated: false) }
            return
        }

        scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y

        if self.shouldUpdateToolbar {
            var newH: CGFloat
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
//            let inset = -Const.toolbarHeight + toolbarH
//            scrollView.contentInset.bottom = inset
//            scrollView.scrollIndicatorInsets.bottom = inset

            let alpha = pct * 3 - 2
            vc.toolbar.contentsAlpha = alpha
        }
    }

    var dragStartScrollY: CGFloat = 0
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartScrollY = scrollView.contentOffset.y
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !scrollView.isOverScrolledTop else { return }

        if scrollView.isOverScrolledBottom || scrollView.contentOffset.y == scrollView.maxScrollYWithInset {
            vc.showToolbar(animated: true, adjustScroll: true)
            return
        }

        if vc.isDisplayingSearch {
            vc.showToolbar(animated: false, adjustScroll: false)
            return
        }

        let dragAmount = scrollView.contentOffset.y - dragStartScrollY

        if scrollDelta > 1 {
            vc.hideToolbar()
        } else if scrollDelta < -1 {
            vc.showToolbar()
        } else if dragAmount > 1 {
            vc.hideToolbar()
        } else if dragAmount < -1 {
            vc.showToolbar()
        }

        if !decelerate {
            vc.updateSnapshot()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        vc.updateSnapshot()
    }

    let vProgressScaleMultiplier: CGFloat = 0
    let vProgressCancelBackScaleMultiplier: CGFloat = 0.2
    let cantGoBackScaleMultiplier: CGFloat = 1.2
    let backItemScale: CGFloat = 0.97

    var wouldCommitPreviousX = false
    var wouldCommitPreviousY = false

    func dismissScaleFor(translation: CGPoint, multiplier: CGFloat? = nil) -> CGFloat {
        let sign = multiplier ?? (translation.x > 0 ? 1 : -1)
        let verticalProgress = translation.y.progress(0, 200).clip()
        let hProg = (elasticLimit(translation.x) / view.bounds.width * sign).clip()
        return 1 - hProg * cantGoBackScaleMultiplier - verticalProgress * vProgressScaleMultiplier
    }

    func gestureChange(_ gesture: UIPanGestureRecognizer) {
        guard isDismissing else { return }
//        guard isDismissing && (direction == .leftToRight || direction == .rightToLeft) else { return }

        let gesturePos = gesture.translation(in: view)

        let revealProgress = min(abs(gesturePos.x) / 200, 1)

        let rad = min(Const.cardRadius + revealProgress * 4 * Const.thumbRadius, Const.thumbRadius)
        if Const.cardRadius < Const.thumbRadius {
            cardView.radius = rad
            mockCardView.radius = rad
        }

        let xShift = gesturePos.x - startPoint.x
        let yShift = gesturePos.y

        let verticalProgress = gesturePos.y.progress(0, 200).clip()

//        let sign : CGFloat = adjustedX > 0 ? 1 : -1 //direction == .left ? 1 : -1
        let sign: CGFloat = direction == .rightToLeft ? -1 : 1
        let dismissScale = dismissScaleFor(translation: CGPoint(x: xShift, y: yShift), multiplier: sign)
        let hintScale = verticalProgress.lerp(1, dismissScale)
        let backScale = xShift.progress(0, 400).lerp(backItemScale, 1)

        let spaceW = cardView.bounds.width * ( 1 - dismissScale )
        let spaceH = cardView.bounds.height * ( 1 - dismissScale )

        cardScaler.dismissState = dismissScale
        thumbScaler.pagingState = 1
        thumbScaler.dismissState = dismissScale
        mockCardView.scaler.dismissState = dismissScale

        let isToParent = (direction == .leftToRight || direction == .top) && !vc.webView.canGoBack && canGoBackToParent
        let cantPage = (direction == .leftToRight && !vc.webView.canGoBack && !isToParent)
                    || (direction == .rightToLeft && !vc.webView.canGoForward)

        let dismissingPoint = CGPoint(
            x: view.center.x + xShift * 0.5 + spaceW * 0.25 * sign,
//            x: view.center.x + spaceW * 0.5 * sign,
            y: view.center.y + max(elasticLimit(yShift), yShift) + spaceH * 0.2
        )
        mockCardView.positioner.dismissState = CGPoint(
            x: view.center.x - view.bounds.width * sign,
            y: view.center.y)

        let backFwdPoint = CGPoint(
            x: view.center.x + xShift,
            y: view.center.y + (yShift > 0 ? yShift : 0))

        let amtOver = min(0, yShift)
        vc.webView.scrollView.setScrollSilently(y: startScroll.y - 0.5 * elasticLimit(amtOver, constant: 60))

        cardScaler.pagingState = hintScale
        thumbScaler.pagingState = hintScale

        let pagingHint = yShift.progress(0, 360).clip()

        var cardPagingPoint: CGPoint

        // reveal back page from left
        if ((direction == .leftToRight || direction == .top) && vc.webView.canGoBack) || isToParent {
            mockCardView.darkener.pagingState = xShift.progress(0, 400).lerp(0.4, 0.1)

            let mockPagingPoint = CGPoint(
                x: view.center.x + xShift * parallaxAmount - view.bounds.width * parallaxAmount * hintScale,
                y: backFwdPoint.y )
            let mockBlendedPoint = pagingHint.lerp(mockPagingPoint, dismissingPoint)
            let cardBlendedPoint = pagingHint.lerp(backFwdPoint, dismissingPoint)
            cardPagingPoint = cardBlendedPoint //CGPoint(x: backFwdPoint.x, y: mockBlendedPoint.y)
            cardPositioner.pagingState = cardPagingPoint
            mockCardView.scaler.pagingState = backScale * hintScale
            mockCardView.positioner.dismissState = dismissingPoint

            mockCardView.darkener.dismissState = isToParent ? 0.2 : 0.7
            mockCardView.positioner.pagingState = mockBlendedPoint
            mockCardView.scaler.dismissState = dismissScale * backItemScale
        }

        // overlay forward page from right
        else if direction == .rightToLeft && vc.webView.canGoForward {
            let pagingPoint = CGPoint(
                x: view.center.x + xShift * parallaxAmount,
                y: backFwdPoint.y )
            cardPagingPoint = pagingHint.lerp(pagingPoint, dismissingPoint)
            cardPositioner.pagingState = cardPagingPoint

            let isBackness = xShift.progress(0, -400) * gesturePos.y.progress(100, 160).clip().reverse()
            vc.overlay.alpha = isBackness.lerp(0, 0.4)

            let pageScale = xShift.progress(0, -400).lerp(1, 0.95)
            cardScaler.pagingState = pageScale * hintScale

            let hintX = yShift.progress(0, 240).lerp(0, -xShift)

            mockCardView.darkener.pagingState = 0
            mockCardView.scaler.pagingState = 1
            mockCardView.scaler.dismissState = 1
            mockCardView.positioner.pagingState = CGPoint(
                x: view.center.x + xShift + view.bounds.width + hintX,
                y: view.center.y )
        }

        // rubber band
        else {
            let unBlendedCardPagingPoint = CGPoint(
                x: view.center.x + elasticLimit(xShift, constant: 100),
                y: backFwdPoint.y )
            cardPagingPoint = pagingHint.lerp(unBlendedCardPagingPoint, dismissingPoint)
            cardPositioner.pagingState = cardPagingPoint
        }

        cardPositioner.dismissState = dismissingPoint
        thumbPositioner.dismissState = dismissingPoint

//        if isToParent {
//            thumbPositioner.setValue(of: PAGING, to: CGPoint(
//                x: backFwdPoint.x,
//                y: (view.center.y - backFwdPoint.y) - mockCardView.bounds.height * hintScale
//            ))
//        }
//        else {
            thumbPositioner.pagingState = cardPagingPoint
//        }

        let isVerticalDismiss = gesturePos.y > dismissPointPreviewY
        let isHorizontalDismiss = false //abs(adjustedX) > 80
        let newState = (isVerticalDismiss || (cantPage && isHorizontalDismiss))
            ? SpringTransitionState.start
            : SpringTransitionState.end
        dismissSwitch.springState(newState)

        updateStatusBar()
    }

    func endDismiss() {
        isDismissing = false
        tearDownBackToParentGesture()
        dismissingEndedPossible()
        if GESTURE_DEBUG { vc.toolbar.text = "Ended" }
    }

    func horizontalEnd(_ gesture: UIPanGestureRecognizer) {
        if !isDismissing { fatalError("End dimiss called when not dismissing") }
        endDismiss()

        let gesturePos = gesture.translation(in: view)
        let adjustedX = gesturePos.x - startPoint.x
        let vel = gesture.velocity(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
        let isVerticalVel = vel.y > abs(vel.x)

        if isVerticalVel || gesturePos.y > dismissPointY {
            commitDismiss(velocity: vel)
        } else if adjustedX > backPointX && isHorizontal {
            if vc.webView.canGoBack
            && mockCardView.frame.origin.x + mockCardView.frame.width > backPointX {
                let nav = vc.webView.goBack()
                vc.hideUntilNavigationDone(navigation: nav)
                animateCommit(action: .goBack, velocity: vel)
            } else if canGoBackToParent
            && adjustedX > backPointX {
                if let parentTab = vc.currentTab.parentTab {
                    vc.updateSnapshot {
                        let vc = self.vc!
                        self.mockCardView.imageView.image = vc.currentTab.currentVisit?.snapshot
                        vc.setTab(parentTab)
                        self.animateCommit(action: .goToParent)
                    }
                }
            } else {
                commitCancel(velocity: vel)
            }
        } else if adjustedX < -backPointX && isHorizontal {
            if vc.webView.canGoForward {
                let nav = vc.webView.goForward()
                vc.hideUntilNavigationDone(navigation: nav)
                animateCommit(action: .goForward, velocity: vel)
            } else {
                commitCancel(velocity: vel)
            }
        } else {
            commitCancel(velocity: vel)
        }
    }

    func resetMockCardView() {
        mockCardView.transform = .identity
        mockCardView.center = vc.view.center
        mockCardView.center.x += cardView.bounds.width
        mockCardView.bounds = cardView.bounds
    }

    func setupBackGesture() {
        resetMockCardView()
        guard let backItem = vc.webView.backForwardList.backItem?.visit else { return }
        mockCardView.setVisit(backItem)
        view.addSubview(mockCardView)
        view.bringSubview(toFront: cardView)
    }

    func setupForwardGesture() {
        resetMockCardView()
        guard let fwdItem = vc.webView.backForwardList.forwardItem?.visit else { return }
        mockCardView.setVisit(fwdItem)
        view.addSubview(mockCardView)
    }

    func setupBackToParentGesture() {
        guard let parent = vc.currentTab.parentTab,
            let parentPage = parent.currentVisit else { return }
        view.insertSubview(mockCardView, belowSubview: cardView)
        mockCardView.setVisit(parentPage)
//        vc.tabSwitcher.setParentHidden(parent, hidden: true)
    }

    func tearDownBackToParentGesture() {
        guard let parent = vc.currentTab.parentTab else { return }
        vc.tabSwitcher.setParentHidden(parent, hidden: false)
    }

    func cancelGesturesInWebview() {
        vc.webView.gestureRecognizers?.forEach {
            $0.isEnabled = false
            $0.isEnabled = true
        }
    }

    func considerStarting(gesture: UIPanGestureRecognizer) {
        if isDismissing {
            fatalError("consider starting dismiss when previous dismissal hasn't ended")
        }
        if pinchController.isPinchDismissing || (vc.isDisplayingSearch && vc.searchVC.isSwiping) {
            dismissingEndedPossible()
            return
        }

        let scrollView = vc.webView.scrollView
        let scroll = scrollView.contentOffset
        if scrollView.isZooming || scrollView.isZoomBouncing { return }

        if vc.isDisplayingSearch {
            vc.searchVC.dismissSelf()
        }

        // let gestureVel = gesture.velocity(in: view)
        let gesturePos = gesture.translation(in: view)
        let isHorizontal = abs(gesturePos.y) < abs(gesturePos.x)
//        let hasHorizontalVel = abs(gestureVel.x) > 300

        let hScrollingPage = scrollView.isScrollableX && isHorizontal
        let fakeHScrollingPage = !scrollView.isScrollableX && isHorizontal

        let hasMoved = abs(gesturePos.x) > 10 || abs(gesturePos.y) > 10
        let isGestureDown = gesturePos.y > 0
        let isGestureLeft = gesturePos.x > 0
        let isGestureRight = gesturePos.x < 0

        let triggerDismissTop = isGestureDown && (
            scrollView.isScrollableY && scroll.y <= 0
            || !scrollView.isScrollableY && scroll.y < 0
        )
        let triggerDismissLeft = isGestureLeft && (
            (hScrollingPage && scroll.x <= 0)
            || (fakeHScrollingPage && scroll.x < 0)
        )
        let triggerDismissRight = isGestureRight && (
            (hScrollingPage && scroll.x >= scrollView.maxScrollX)
            || (fakeHScrollingPage && scroll.x > scrollView.maxScrollX)
        )

        if triggerDismissTop {
            startDismiss(gesture, direction: .top)
        } else if triggerDismissLeft {
            startDismiss(gesture, direction: .leftToRight)
        } else if triggerDismissRight {
            startDismiss(gesture, direction: .rightToLeft)
        } else if hasMoved {
            // if we are swiping horizontally and the above conditions have not
            // triggered a dismiss, dismissing should no longer be possible
            // during this gesture
            dismissingEndedPossible()
        }
    }

    var startAnchorOffsetPct: CGFloat = 0

    func startDismiss(_ gesture: UIPanGestureRecognizer, direction newDir: GestureNavigationDirection) {
        isDismissing = true
        dismissingEndedPossible()
        if GESTURE_DEBUG { vc.toolbar.text = "Started" }

        vc.searchVC.dismissSelf()

        vc.tabSwitcher.moveTabToEnd(vc.currentTab)
        vc.tabSwitcher.scrollToBottom()

        direction = newDir
        startPoint = gesture.translation(in: view)

        startAnchorOffsetPct = gesture.location(in: view).y / view.bounds.height

        startScroll = vc.webView.scrollView.contentOffset
        vc.webView.scrollView.showsVerticalScrollIndicator = false
        vc.webView.scrollView.cancelScroll()

        vc.currentTab.updateSnapshot(from: vc.webView)
        vc.contentView.radius = Const.cardRadius

        cancelGesturesInWebview()

        if direction == .leftToRight || direction == .top {
            if vc.webView.canGoBack {
                setupBackGesture()
            } else {
                setupBackToParentGesture()
            }
        } else if direction == .rightToLeft {
            if vc.webView.canGoForward { setupForwardGesture() }
        }
        dismissSwitch.setState(SpringTransitionState.end)
        gestureChange(gesture)
    }

    func commitDismiss(velocity vel: CGPoint) {
        dismissVelocity = vel
        dismissSwitch.cancel()
        if let parent = vc.currentTab.parentTab {
            vc.tabSwitcher.setParentHidden(parent, hidden: false)
        }

        // hack to sync with collectionview update
//        DispatchQueue.main.async {
//            self.mockCardView.removeFromSuperview()
//            self.mockCardView.imageView.image = nil
//        }

        vc.dismiss(animated: true) {
            self.dismissVelocity = nil
        }
    }

    func swapTo(childTab: Tab) {
        let parentMock = cardView.snapshotView(afterScreenUpdates: false)!
        parentMock.contentMode = .top
        parentMock.clipsToBounds = true
        parentMock.radius = Const.cardRadius

        vc.view.insertSubview(parentMock, belowSubview: cardView)
        vc.contentView.radius = Const.cardRadius

        vc.updateSnapshot {
            let vc = self.vc!
            vc.setTab(childTab)
//            vc.cardView.center.y = vc.view.center.y + vc.cardView.bounds.height + self.mockCardViewSpacer
            vc.cardView.center.x = vc.view.center.x + vc.cardView.bounds.width

            UIView.animate(
                withDuration: 0.6,
                delay: 0.0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.0,
                options: .allowUserInteraction,
                animations: {
                    vc.cardView.center = vc.view.center
//                    parentMock.center.y -= vc.view.bounds.height + self.mockCardViewSpacer
                    parentMock.scale = 0.95
                    parentMock.alpha = 0
            }, completion: { _ in
                parentMock.removeFromSuperview()
                vc.contentView.radius = 0
            })
        }
    }

    func swapTo(parentTab: Tab) {
        let childMock = cardView.snapshotView(afterScreenUpdates: false)!
        childMock.contentMode = .top
        childMock.clipsToBounds = true
        childMock.radius = Const.cardRadius

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
            }, completion: { _ in
                childMock.removeFromSuperview()
                vc.isSnapshotMode = false // WHy?
            })
        }
    }

    func swapCardAndPlaceholder(for action: GestureNavigationAction) {
        // Swap image
        vc.setSnapshot(mockCardView.imageView.image)
        if action != .goToParent { // because goToParent swaps images itself
            if let currentSnap = vc.currentTab.currentVisit?.snapshot {
                mockCardView.setSnapshot(currentSnap)
            }
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

        // Make sure toolbar is expanded
        vc.showToolbar(animated: false, adjustScroll: false)

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

        mockCardView.positioner.end = self.view.center
        let mockShift = mockCardView.bounds.width
        if action == .goBack || action == .goToParent {
            mockCardView.positioner.end.x += mockShift
        }
//        else if action == .goToParent {
//            mockPositioner.end.x = view.center.x
//            mockPositioner.end.y = view.center.y + view.bounds.height
//        }
        else if action == .goForward {
            mockCardView.positioner.end.x -= mockShift * parallaxAmount
        }

        if action == .goToParent {
            // TODO: this makes sure webview isnt hidden, hack
            self.vc.isSnapshotMode = false
        }

        // dont use velocity for this part, since it
        // wasn't directly tracking gesture
        let cardAnim = cardView.springCenter(to: view.center, at: adjustedVel) {_, _ in
            self.vc.resetSizes()
            self.vc.view.bringSubview(toFront: self.cardView)
            self.vc.contentView.radius = 0

            UIView.animate(withDuration: 0.2, animations: {
                self.vc.tabSwitcher.setNeedsStatusBarAppearanceUpdate()
            })
            if action == .goToParent {
                self.vc.isSnapshotMode = false
            }
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
        }

        let mockAnim = mockCardView.springCenter(to: mockCardView.positioner.end, at: adjustedVel) {_, _ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        if action == .goToParent {
            cardAnim?.springBounciness = 2
            mockAnim?.springBounciness = 2
        }

        mockCardView.springScale(to: action == .goForward ? backItemScale : 1)
        cardView.springScale(to: 1)

        UIView.animate(withDuration: 0.3) {
            self.vc.overlay.alpha = 0
        }
    }
    let parallaxAmount: CGFloat = 0.3

    func commitCancel(velocity: CGPoint) {
        dismissSwitch.cancel()

        vc.webView.scrollView.cancelScroll()

        var hVel = velocity
        hVel.y = 0

        // Move card back to center
        let centerAnim = cardView.springCenter(to: view.center, at: velocity) {_, _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.vc.tabSwitcher.setNeedsStatusBarAppearanceUpdate()
            })
            self.vc.webView.scrollView.showsVerticalScrollIndicator = true
            self.vc.contentView.radius = 0
        }
        centerAnim?.animationDidApplyBlock = { _ in
            self.vc.tabSwitcher.updateStackOffset(for: self.cardView.center)
        }
        let scaleAnim = cardView.springScale(to: 1)
        scaleAnim?.animationDidApplyBlock = { _ in
            self.vc.tabSwitcher.setThumbScale(self.cardView.scale)
        }

        var mockCenter = self.view.center
        var mockScale = backItemScale
        let mockShift = mockCardView.bounds.width
        if mockCardView.center.y < view.center.y - 200 { // upward
            mockCenter.y -= view.bounds.height
        } else if mockCardView.center.x > view.center.x { // forward
            mockCenter.x += mockShift
            mockScale = 1
        } else {
            mockCenter.x -= mockShift * parallaxAmount // back
        }

        /* don't use velocity for this */
        mockCardView.springCenter(to: mockCenter, at: hVel) {_, _ in
            self.mockCardView.removeFromSuperview()
            self.mockCardView.imageView.image = nil
        }
        mockCardView.springScale(to: 1)
        mockCardView.springScale(to: mockScale)

        vc.tabSwitcher.setThumbsVisible()

        UIView.animate(withDuration: 0.2) {
            self.vc.overlay.alpha = 0
            self.vc.statusBar.label.alpha = 0
        }
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
        vc.webView.scrollView.showsVerticalScrollIndicator = true
        if GESTURE_DEBUG { vc.toolbar.text = "Not Possible" }
    }

    func dismissingBecamePossible() {
        let mask = UIView()
        mask.backgroundColor = .red
        mask.frame = vc.cardView.bounds
        vc.cardView.mask = mask
        isDismissingPossible = true
        vc.webView.scrollView.showsVerticalScrollIndicator = false
        if GESTURE_DEBUG { vc.toolbar.text = "Possible" }
    }

    @objc func leftEdgePan(gesture: UIScreenEdgePanGestureRecognizer) {
        switch gesture.state {
        case .began:
            if isDismissing { return }
            startDismiss(gesture, direction: .leftToRight)
            startPoint = .zero
            vc.showToolbar()
        case .changed:
            if isDismissing { gestureChange(gesture) }
        case .ended:
            if isDismissing { horizontalEnd(gesture) }
        case .cancelled:
            if isDismissing { horizontalEnd(gesture) }
        default: break
        }
    }

    @objc func rightEdgePan(gesture: UIScreenEdgePanGestureRecognizer) {
        switch gesture.state {
        case .began:
            if isDismissing { return }
            startDismiss(gesture, direction: .rightToLeft)
            startPoint = .zero
            vc.showToolbar()
        case .changed:
            if isDismissing { gestureChange(gesture) }
        case .ended:
            if isDismissing { horizontalEnd(gesture) }
        case .cancelled:
            if isDismissing { horizontalEnd(gesture) }
        default: break
        }
    }

    @objc func anywherePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            if isDismissing { return }
            dismissingBecamePossible()
            considerStarting(gesture: gesture)
        case .changed:
            if isDismissing {
                gestureChange(gesture)
            } else if isDismissingPossible {
                considerStarting(gesture: gesture)
            }
        case .ended:
            if isDismissing { horizontalEnd(gesture) }
            dismissingEndedPossible()
        case .cancelled:
            if isDismissing { horizontalEnd(gesture) }
            dismissingEndedPossible()
        default: break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // TODO: Want to recognize swipe with scroll,
        // but not edgeswipe and real swipe at same time
        return true
    }
}
// swiftlint:disable:next file_length

