//
//  CustomPresentAnimationController.swift
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
        let homeVC = homeNav.topViewController as! HomeViewController
        
        // TODO: This is not necessarily the correct thumb.
        // When swapping between tabs it gets mixed up.
        homeVC.visibleCells.forEach { $0.isHidden = false }
        let thumb = homeVC.thumb(forTab: browserVC.browserTab!)
        thumb?.isHidden = true
        
        if isExpanding {
            browserVC.resetSizes(withKeyboard: browserVC.isBlank)
            containerView.addSubview(browserVC.view)
        }
        else {
            homeVC.setThumbPosition(expanded: true)
            browserVC.updateSnapshot()
        }
        
        let scrollView = browserVC.webView.scrollView
        scrollView.isScrollEnabled = false
        scrollView.cancelScroll()
        browserVC.isExpandedSnapshotMode = !self.isExpanding
        browserVC.isSnapshotMode = true
        
        let prevTransform = homeNav.view.transform
        homeNav.view.transform = .identity // HACK reset to identity so we can get frame
        
        var thumbCenter : CGPoint
        var thumbOverlayAlpha : CGFloat = 0
        
        if thumb != nil {
            // must be after toVC is added
            let cv = homeVC.collectionView!
            let selIndexPath = cv.indexPath(for: thumb!)!
            let attr = cv.layoutAttributesForItem(at: selIndexPath)!
            let selectedThumbCenter = attr.center
            thumbOverlayAlpha = 1 - attr.alpha
            thumbCenter = containerView.convert(selectedThumbCenter, from: thumb?.superview)
        }
        else {
            // animate from bottom
            let y = (homeVC.navigationController?.view.frame.height)!
            thumbCenter = CGPoint(x: homeVC.view.center.x, y: y / 2)
        }
        
        let expandedCenter = browserVC.cardView.center
        let expandedBounds = browserVC.cardView.bounds
        let thumbBounds = homeVC.boundsForThumb(forTab: browserVC.browserTab) ?? CGRect(origin: .zero, size: homeVC.thumbSize)

        homeNav.view.transform = self.isExpanding ? .identity : prevTransform
        
        browserVC.cardView.center = isExpanding ? thumbCenter : expandedCenter
        browserVC.cardView.bounds = isExpanding ? thumbBounds : expandedBounds
        browserVC.updateSnapshotPosition()

        homeVC.visibleCellsBelow.forEach { containerView.addSubview($0) }

        
        let newCenter = isExpanding ? expandedCenter : thumbCenter
        let velocity = browserVC.gestureController.dismissVelocity ?? .zero
        
        browserVC.cardView.springScale(to: 1)
        browserVC.cardView.springCenter(to: newCenter, at: velocity, with: POPtions(mass: 1.3, friction: 35), then: { (_, _) in
            
            browserVC.isSnapshotMode = false
            browserVC.webView.scrollView.isScrollEnabled = true
            thumb?.setTab(browserVC.browserTab!)
            
            homeVC.visibleCellsBelow.forEach { homeVC.collectionView?.addSubview($0) }
            
            if self.isDismissing {
                homeVC.visibleCells.forEach { $0.isHidden = false }
                browserVC.view.removeFromSuperview()
                homeVC.setThumbPosition(expanded: false)
                homeVC.setNeedsStatusBarAppearanceUpdate()
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })

        
        UIView.animate(
            withDuration: 0.6,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                
//            browserVC.cardView.center = self.isExpanding ? expandedCenter : thumbCenter
            browserVC.cardView.bounds = self.isExpanding ? expandedBounds : thumbBounds
//            browserVC.cardView.transform = .identity
            browserVC.overlay.alpha = self.isExpanding ? 0 : thumbOverlayAlpha
            browserVC.isExpandedSnapshotMode = self.isExpanding
            browserVC.updateSnapshotPosition()
            browserVC.roundedClipView.layer.cornerRadius = self.isExpanding ? Const.shared.cardRadius : Const.shared.thumbRadius

            homeNav.view.alpha = self.isExpanding ? 0.4 : 1
            
            homeVC.setThumbPosition(expanded: self.isExpanding)
            homeVC.visibleCellsBelow.forEach { $0.center.y += -homeVC.collectionView!.contentOffset.y }

            homeVC.setNeedsStatusBarAppearanceUpdate()
                
        }, completion: { finished in
            
        })
    }
}
