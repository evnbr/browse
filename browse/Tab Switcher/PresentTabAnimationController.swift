//
//  PresentTabAnimationController.swift
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

class PresentTabAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    
    var direction : CustomAnimationDirection!
    var isExpanding  : Bool { return direction == .present }
    var isDismissing : Bool { return direction == .dismiss }

        
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let homeNav = (isExpanding ? fromVC : toVC) as! UINavigationController
        let browserVC = (isExpanding ? toVC : fromVC) as! BrowserViewController
        let homeVC = homeNav.topViewController as! TabSwitcherViewController
        
        let snapFab = homeVC.fabSnapshot
        homeVC.fab.isHidden = true

        // TODO: This is not necessarily the correct thumb.
        // When swapping between tabs it gets mixed up.
        homeVC.visibleCells.forEach { $0.isHidden = false }
        let thumb = homeVC.thumb(forTab: browserVC.currentTab!)
        thumb?.isHidden = true
        browserVC.statusBar.isHidden = false // TODO
        
        if isExpanding {
            browserVC.resetSizes(withKeyboard: browserVC.isBlank)
            containerView.addSubview(browserVC.view)
        }
        else {
            homeVC.scrollToBottom()
            browserVC.updateSnapshot()
        }
        
        let scrollView = browserVC.webView.scrollView
        scrollView.isScrollEnabled = false
        scrollView.cancelScroll()
//        browserVC.isSnapshotMode = true
        
        var thumbCenter : CGPoint
        var thumbScale : CGFloat = 1
        var thumbOverlayAlpha : CGFloat = 0
        
        if let thumb = thumb {
            // must be after toVC is added
            let cv = homeVC.collectionView!
            let selIndexPath = cv.indexPath(for: thumb)!
            let attr = cv.layoutAttributesForItem(at: selIndexPath)!
            let selectedThumbCenter = attr.center
            thumbOverlayAlpha = 1 - attr.alpha
            thumbCenter = containerView.convert(selectedThumbCenter, from: thumb.superview)
            thumbScale = attr.transform.xScale
        }
        else {
            // animate from bottom
            thumbCenter = CGPoint(x: homeVC.view.center.x, y: homeVC.view.center.y + (homeVC.view.bounds.height))
        }
        
        let expandedCenter = browserVC.cardView.center
        let expandedBounds = browserVC.cardView.bounds
        let thumbBounds = homeVC.boundsForThumb(forTab: browserVC.currentTab) ?? CGRect(origin: .zero, size: expandedBounds.size)
        
        let mask = UIView()
        mask.backgroundColor = .red
        mask.frame = isExpanding ? thumbBounds : expandedBounds
        mask.radius = isExpanding ? Const.shared.thumbRadius : Const.shared.cardRadius

        // Avoid adjusting height: TODO just mask instead
        thumbCenter.y += (expandedBounds.size.height - thumbBounds.size.height) / 2
        
        var smallerBounds = thumbBounds
        smallerBounds.size.height = expandedBounds.size.height
        
        browserVC.overlay.alpha = thumbOverlayAlpha
        browserVC.cardView.center = isExpanding ? thumbCenter : expandedCenter
        browserVC.cardView.bounds = isExpanding ? smallerBounds : expandedBounds
        browserVC.contentView.mask = mask
        
        if isExpanding {
            browserVC.cardView.scale = thumbScale
        }

        homeVC.visibleCellsBelow.forEach {
            containerView.addSubview($0)
            if let scroll = homeVC.collectionView?.contentOffset.y {
                $0.center.y -= scroll
            }
        }
        
        let newCenter = isExpanding ? expandedCenter : thumbCenter
        let velocity = browserVC.gestureController.dismissVelocity ?? .zero
        
        var popCenterDone = false
        var viewAnimFinished = false
        var popBoundsDone = false
        
        func finishTransition() {
            if self.isExpanding {
                browserVC.isSnapshotMode = false
                browserVC.webView.scrollView.isScrollEnabled = true
                browserVC.webView.scrollView.showsVerticalScrollIndicator = true
            }
            thumb?.setTab(browserVC.currentTab!)
            
            homeVC.visibleCellsBelow.forEach { homeVC.collectionView?.addSubview($0) }
            
            if self.isDismissing {
                browserVC.view.removeFromSuperview()
                homeVC.setThumbPosition(switcherProgress: 1, isSwitcherMode: true)
            }
            snapFab?.removeFromSuperview()
            homeVC.fab.isHidden = self.isExpanding
            browserVC.contentView.mask = nil
            browserVC.contentView.radius = 0
            homeVC.setThumbsVisible()
            homeVC.setNeedsStatusBarAppearanceUpdate()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            homeVC.updateThumbs()
            homeVC.collectionView?.reloadData() // TODO: touch targets dont work without this
        }
        func maybeFinish() {
            if viewAnimFinished
            && popCenterDone
            && popBoundsDone {
                finishTransition()
            }
        }
        
        let isLandscape = browserVC.view.bounds.width > browserVC.view.bounds.height
        let statusHeight : CGFloat = isLandscape ? 0 : Const.statusHeight
        
        browserVC.statusHeightConstraint.springConstant(to: isExpanding ? statusHeight : THUMB_OFFSET_COLLAPSED )
        browserVC.cardView.springScale(to: isExpanding ? 1 : thumbScale)
        browserVC.cardView.springBounds(to: isExpanding ? expandedBounds : smallerBounds, then: {  _, _ in
//            popBoundsDone = true
//            maybeFinish()
        })
        let maskAnim = mask.springFrame(to: isExpanding ? expandedBounds : thumbBounds) { _, _ in
            popBoundsDone = true
            maybeFinish()
        }
        maskAnim?.springBounciness = 2
        
        let centerAnim = browserVC.cardView.springCenter(to: newCenter, at: velocity) { (_, _) in
            popCenterDone = true
            maybeFinish()
        }
//        centerAnim?.dynamicsMass = 1.3
//        centerAnim?.dynamicsFriction = 35
        centerAnim?.springSpeed = 10
        centerAnim?.springBounciness = 2
        homeVC.springCards(expanded: isExpanding, at: velocity)
        

        if let fab = snapFab {
            containerView.addSubview(fab)
            fab.layer.zPosition = 99
            let currFabCenter = homeVC.fab.center
            var endFabCenter = currFabCenter
            endFabCenter.y += 120
            fab.center = isExpanding ? currFabCenter : endFabCenter
            fab.springCenter(to: isExpanding ? endFabCenter : currFabCenter)
        }

        browserVC.statusBar.frame.size.height = !isExpanding ? statusHeight : THUMB_OFFSET_COLLAPSED
        browserVC.statusBar.label.text = browserVC.webView.title
        
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
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
            
            browserVC.statusBar.backgroundView.alpha = 1
            browserVC.overlay.alpha = self.isExpanding ? 0 : thumbOverlayAlpha
            browserVC.contentView.radius = self.isExpanding ? Const.shared.cardRadius : Const.shared.thumbRadius
            mask.radius = self.isExpanding ? Const.shared.cardRadius : Const.shared.thumbRadius
            homeNav.view.alpha = self.isExpanding ? 0.7 : 1
            
            homeVC.setNeedsStatusBarAppearanceUpdate()
                
        }, completion: { finished in
            viewAnimFinished = true
            maybeFinish()
        })
    }
    
}
