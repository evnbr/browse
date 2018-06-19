//
//  StackAnimatedTransitioning.swift
//  browse
//
//  Created by Evan Brooks on 5/31/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  Based on http://www.appcoda.com/custom-view-controller-transitions-tutorial/
//  https://www.raywenderlich.com/146692/ios-animation-tutorial-custom-view-controller-presentation-transitions-2

import UIKit
import pop

enum CustomAnimationDirection {
    case present
    case dismiss
}

extension UIScrollView {
    func cancelScroll() {
        setContentOffset(self.contentOffset, animated: false)
    }
}


func quadraticArc(_ t: CGFloat) -> CGFloat {
    return ((t - 0.5) * (t - 0.5) * -2 + 0.5) * 2
}
// TODO: Shouldn't change state permanently here.

class CardStackTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    var direction : CustomAnimationDirection!
    var isExpanding  : Bool { return direction == .present }
    var isDismissing : Bool { return direction == .dismiss }
    var useArc: Bool = true
    var fromBottom: Bool = false
    var isTransitioning: Bool = false
        
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        isTransitioning = true
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let homeNav = (isExpanding ? fromVC : toVC) as! UINavigationController
        let browserVC = (isExpanding ? toVC : fromVC) as! BrowserViewController
        let tabSwitcher = homeNav.topViewController as! TabSwitcherViewController
        
        let snapFab = tabSwitcher.fabSnapshot
        tabSwitcher.fab.isHidden = true
        // TODO: This is not necessarily the correct thumb.
        // When swapping between tabs it gets mixed up.
//        homeVC.setThumbsVisible()
        
        if isExpanding {
            browserVC.resetSizes()
            containerView.addSubview(tabSwitcher.view)
            containerView.addSubview(browserVC.view)
        }
        else {
            browserVC.updateSnapshot {
                browserVC.isSnapshotMode = true
            }
        }
        
        let scrollView = browserVC.webView.scrollView
//        scrollView.isScrollEnabled = false
        scrollView.cancelScroll()
        
        var thumbCenter : CGPoint
        var thumbScale : CGFloat = 1
        var thumbOverlayAlpha : CGFloat = 0
        
        var expandedTransform = CATransform3DIdentity
        let bScale = browserVC.cardView.scale
        expandedTransform = CATransform3DScale(expandedTransform, bScale, bScale, bScale)
        var stackTransform = CATransform3DIdentity
        
        if let ip = tabSwitcher.currentIndexPath,
            let cv = tabSwitcher.collectionView,
            !fromBottom {
            
//            let attr = homeVC.stackedLayout.layoutAttributesForItem(at: ip)
            let attr = tabSwitcher.cardStackLayout.calculateItem(
                for: ip,
                whenStacked: true,
                scrollY: cv.contentOffset.y,
                baseCenter: cv.center,
                baseScale: 1,
                totalItems: cv.numberOfItems(inSection: 0),
                withXOffset: false,
                withYOffset: false)
            
            // must be after toVC is added
            let selectedThumbCenter = attr.center
            
            thumbOverlayAlpha = 1 - attr.alpha
            thumbCenter = containerView.convert(selectedThumbCenter, from: cv)
            thumbScale = attr.transform.xScale
            
            if isExpanding {
                thumbScale *= tapScaleAmount
            }
            
//            let s = thumbScale * 0.9
//            var tf = CATransform3DIdentity
//            tf.m34 = 1.0 / -4000.0
//            let rotated = CATransform3DRotate(tf, CGFloat.pi * -0.3, 1.0, 0.0, 0.0)
//            let scaled = CATransform3DScale(rotated, s, s, s)
//            stackTransform = scaled
        }
        else {
            // If can't find end point for some reason, just animate to/from bottom
            print("card from bottom")
            thumbCenter = CGPoint(x: tabSwitcher.view.center.x, y: tabSwitcher.view.center.y + (tabSwitcher.view.bounds.height))
        }

        let expandedCenter = browserVC.cardView.center
        let expandedBounds = browserVC.cardView.bounds
        let thumbBounds = tabSwitcher.boundsForThumb(forTab: browserVC.currentTab) ?? CGRect(origin: .zero, size: expandedBounds.size)
        
        let mask = UIView()
        mask.backgroundColor = .red
        mask.frame = isExpanding ? thumbBounds : expandedBounds
        mask.radius = isExpanding ? Const.thumbRadius : Const.cardRadius

        // Avoid adjusting height: TODO just mask instead
        thumbCenter.y += (expandedBounds.size.height - thumbBounds.size.height) / 2

        var smallerBounds = thumbBounds
        smallerBounds.size.height = expandedBounds.size.height
        
        browserVC.gradientOverlay.alpha = isExpanding ? 1 : 0
        browserVC.overlay.alpha = thumbOverlayAlpha
        browserVC.cardView.center = isExpanding ? thumbCenter : expandedCenter
        browserVC.contentView.mask = mask
        
        if isExpanding {
            browserVC.cardView.scale = thumbScale
        }
        
        tabSwitcher.cardStackLayout.belowHidden = true
        var snaps: [ UIView ] = []
        tabSwitcher.visibleCellsBelow.forEach {
            guard let snap = $0.snapshotView(afterScreenUpdates: false) else { return }
            var center = containerView.convert($0.center, from: $0.superview!)
            snap.center = center
            snap.scale = $0.scale
            snaps.append(snap)
            containerView.addSubview(snap)
        }
        snaps.forEach { snap in
            var endCenter = containerView.center
            endCenter.y += containerView.bounds.height
            snap.springCenter(to: endCenter) {_,_ in
                snap.removeFromSuperview()
            }
        }
        
        let newCenter = isExpanding ? expandedCenter : thumbCenter
        let velocity = browserVC.gestureController.dismissVelocity ?? .zero
        
        var popCenterDone = false
        var viewAnimFinished = false
        
        func finishTransition() {
            guard viewAnimFinished && popCenterDone else {  return }
            if self.isExpanding {
                browserVC.isSnapshotMode = false
//                browserVC.webView.scrollView.isScrollEnabled = true
                browserVC.webView.scrollView.showsVerticalScrollIndicator = true
            }
            if self.isDismissing {
                tabSwitcher.cardStackLayout.selectedHidden = false
                tabSwitcher.cardStackLayout.isTransitioning = false
                browserVC.gestureController.mockCardView.removeFromSuperview()
            }
            
            snapFab?.removeFromSuperview()
            
            tabSwitcher.cardStackLayout.belowHidden = false
            tabSwitcher.visibleCells.forEach { $0.reset() }
            tabSwitcher.scrollToBottom()
            tabSwitcher.fab.isHidden = self.isExpanding
            tabSwitcher.cardStackLayout.invalidateLayout()
            tabSwitcher.setNeedsStatusBarAppearanceUpdate()
            
            browserVC.contentView.mask = nil
            browserVC.contentView.radius = 0
            browserVC.cardView.scale = 1
            browserVC.cardView.center = browserVC.view.center

            homeNav.view.addSubview(tabSwitcher.view)
            if self.isDismissing {
                browserVC.view.removeFromSuperview()
                browserVC.gestureController.mockCardView.removeFromSuperview()
                browserVC.gestureController.mockCardView.imageView.image = nil
            }
            isTransitioning = false
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        let isLandscape = browserVC.view.bounds.width > browserVC.view.bounds.height
        let statusHeight : CGFloat = isLandscape ? 0 : Const.statusHeight
        
        browserVC.statusHeightConstraint.springConstant(to: isExpanding ? statusHeight : THUMB_OFFSET_COLLAPSED )
        
//        let scaleAnim = browserVC.cardView.springScale(to: isExpanding ? 0.7 : thumbScale)
        let startScale = browserVC.cardView.scale
        let endThumbScale: CGFloat = 1 //isExpanding ? 1 : thumbScale
        let endCardScale: CGFloat = isExpanding ? 1 : thumbScale
        print(thumbScale)
        let scaleArcInfluence = useArc ? abs(browserVC.cardView.center.y - newCenter.y).progress(0, 600).clip().lerp(0, 0.15) : 0
        let scaleSwitch = SpringSwitch { pct in
            let arc = scaleArcInfluence * quadraticArc(pct)
            let thumbScale = pct.lerp(startScale, endThumbScale) - arc
            let cardScale = pct.lerp(startScale, endCardScale) - arc
            
            browserVC.cardView.scale = cardScale
            tabSwitcher.setThumbScale(thumbScale)
        }
        scaleSwitch.setState(.start)
        let scaleAnim = scaleSwitch.springState(.end)
        
        
        let maskAnim = mask.springFrame(to: isExpanding ? expandedBounds : thumbBounds) { _, _ in
//            popBoundsDone = true
//            finishTransition()
        }
        maskAnim?.springBounciness = 2
        
        let centerAnim = browserVC.cardView.springCenter(to: newCenter, at: velocity) { (_, _) in
            popCenterDone = true
            finishTransition()
        }
//        centerAnim?.dynamicsMass = 5
//        centerAnim?.dynamicsTension = 700
//        centerAnim?.dynamicsFriction = 95
        
        centerAnim?.dynamicsMass = 3.5
        centerAnim?.dynamicsTension = 700
        centerAnim?.dynamicsFriction = 80

        
        scaleAnim?.springSpeed = 8
        scaleAnim?.springBounciness = 2

        let mockMatchCard = browserVC.gestureController.mockCardView.center.x < browserVC.cardView.center.x
        
        let startDist = browserVC.cardView.center.distanceTo(newCenter)
        let startX = browserVC.gestureController.mockCardView.center.x

        centerAnim?.animationDidApplyBlock = { prop in
            let cardCenter = browserVC.cardView.center
            let dist = cardCenter.distanceTo(newCenter)
            let pct = dist.progress(startDist, 0)

            if self.isDismissing {
                var endX = browserVC.view.center.x + browserVC.cardView.bounds.width
                if mockMatchCard {
                    browserVC.gestureController.mockCardView.center.y = cardCenter.y
                    endX = browserVC.cardView.center.x
                }
                browserVC.gestureController.mockCardView.center.x = pct.lerp(startX, endX)
            }
            tabSwitcher.updateStackOffset(for: cardCenter)
            let search = browserVC.searchVC
            let offsetTextField = (cardCenter.y - newCenter.y) * 0.8
            search.kbHeightConstraint?.constant = search.keyboard.height + offsetTextField
        }
        
        scaleAnim?.animationDidApplyBlock = { _ in
            let s = browserVC.cardView.scale
            let gc = browserVC.gestureController!

            if self.isDismissing {
                if mockMatchCard {
                    gc.mockCardView.scale = s * gc.backItemScale
                }
            }
        }

        tabSwitcher.springCards(toStacked: isDismissing, at: velocity)

        if let fab = snapFab {
            containerView.addSubview(fab)
            fab.layer.zPosition = 99
            let currFabCenter = tabSwitcher.fab.center
            var endFabCenter = currFabCenter
            endFabCenter.y += 120
            fab.center = isExpanding ? currFabCenter : endFabCenter
            fab.springCenter(to: isExpanding ? endFabCenter : currFabCenter)
        }

        browserVC.statusBar.frame.size.height = !isExpanding ? statusHeight : THUMB_OFFSET_COLLAPSED
        browserVC.currentTab.currentVisit?.title = browserVC.webView.title
        if let title = browserVC.webView.title, title != "" {
            browserVC.statusBar.label.text = title
        } else {
            browserVC.statusBar.label.text = "New Tab"
        }
        
        if isExpanding {
            UIView.animate(withDuration: 0.2, delay: 0, animations: {
                browserVC.statusBar.label.alpha = 0
            })
        }
        else {
            UIView.animate(withDuration: 0.2, delay: 0.1, animations: {
                browserVC.statusBar.label.alpha = 1
            })
        }
        
//        browserVC.cardView.layer.transform = isExpanding ? stackTransform : expandedTransform
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
            
//            browserVC.cardView.layer.transform = self.isExpanding ? expandedTransform : stackTransform
            browserVC.statusBar.backgroundView.alpha = 1
            browserVC.gradientOverlay.alpha = self.isExpanding ? 0 : 1
            browserVC.overlay.alpha = self.isExpanding ? 0 : thumbOverlayAlpha
            browserVC.contentView.radius = self.isExpanding ? Const.cardRadius : Const.thumbRadius
            mask.radius = self.isExpanding ? Const.cardRadius : Const.thumbRadius
//            homeNav.view.alpha = self.isExpanding ? 0.4 : 1
            browserVC.gestureController.mockCardView.layer.shadowOpacity = 0
                
            tabSwitcher.setNeedsStatusBarAppearanceUpdate()
                
        }, completion: { finished in
            viewAnimFinished = true
            finishTransition()
        })
    }
    
}
