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
    
    var isExpanding : Bool {
        return direction == .present
    }
        
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
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

        if direction == .present {
            browserVC.resetSizes(withKeyboard: browserVC.isBlank)
        }
        
        if isExpanding {
            containerView.addSubview(browserVC.view)
        }
        else {
            homeVC.setThumbPosition(
                expanded: true,
                offsetY: browserVC.cardView.frame.origin.y,
                offsetHeight: (browserVC.cardViewDefaultFrame.height - browserVC.cardView.frame.height)
            )
        }
        
        if !self.isExpanding {
            browserVC.updateSnapshot()
        }
        
        var clipSnapFromBottom = false
        if isExpanding {
            clipSnapFromBottom = thumb?.clipSnapFromBottom ?? false
        }
        else {
            clipSnapFromBottom = browserVC.cardView.frame.origin.y < 0 && abs(browserVC.cardView.frame.origin.x) < 50
        }
        
        let scrollView = browserVC.webView.scrollView
        scrollView.isScrollEnabled = false
        scrollView.cancelScroll()
        browserVC.isExpandedSnapshotMode = !self.isExpanding
        browserVC.isSnapshotMode = true
        
        let prevTransform = homeNav.view.transform
        homeNav.view.transform = .identity // HACK reset to identity so we can get frame
        
//        var thumbFrame : CGRect
        var thumbCenter : CGPoint
        
        if thumb != nil {
            // must be after toVC is added
            let cv = homeVC.collectionView!
            let selIndexPath = cv.indexPath(for: thumb!)!
//            let selectedThumbFrame = cv.layoutAttributesForItem(at: selIndexPath)!.frame
            let selectedThumbCenter = cv.layoutAttributesForItem(at: selIndexPath)!.center

//            thumbFrame = containerView.convert(selectedThumbFrame, from: thumb?.superview)
            
            thumbCenter = containerView.convert(selectedThumbCenter, from: thumb?.superview)
            //            thumbFrame.origin.y -= homeNav.view.frame.origin.y
            //            thumbFrame.origin.x -= homeNav.view.frame.origin.x

        }
        else {
            // animate from bottom
            let y = (homeVC.navigationController?.view.frame.height)!
            thumbCenter = CGPoint(x: homeVC.view.center.x, y: y)
//            thumbFrame = CGRect(origin: CGPoint(x: 0, y: y), size: homeVC.thumbSize)
//            thumbFrame.size.height = 40
        }
        
        let expandedCenter = browserVC.cardView.center
        let expandedBounds = browserVC.cardView.bounds
        let thumbBounds = CGRect(origin: .zero, size: homeVC.thumbSize)

        homeNav.view.transform = self.isExpanding ? .identity : prevTransform
        
        let END_ALPHA : CGFloat = 0.0
        
        browserVC.cardView.center = isExpanding ? thumbCenter : expandedCenter
        browserVC.cardView.bounds = isExpanding ? thumbBounds : expandedBounds
        browserVC.updateSnapshotPosition(fromBottom: clipSnapFromBottom)

        
        // Hack to keep thumbnails from intersecting toolbar
        let newTabToolbar = homeVC.toolbar!
        containerView.addSubview(newTabToolbar)
        containerView.bringSubview(toFront: newTabToolbar)
        
        newTabToolbar.isHidden = false
        newTabToolbar.transform = isExpanding ? .identity : CGAffineTransform(translationX: 0, y: Const.shared.toolbarHeight)

        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                
            browserVC.cardView.center = self.isExpanding ? expandedCenter : thumbCenter
            browserVC.cardView.bounds = self.isExpanding ? expandedBounds : thumbBounds
                
            browserVC.cardView.transform = .identity
            browserVC.isExpandedSnapshotMode = self.isExpanding
            browserVC.updateSnapshotPosition(fromBottom: clipSnapFromBottom)

            browserVC.cardView.layer.cornerRadius = self.isExpanding ? Const.shared.cardRadius : Const.shared.thumbRadius

            homeNav.view.alpha = self.isExpanding ? END_ALPHA : 1.0
            

            if self.isExpanding {
                homeVC.setThumbPosition(
                    expanded: true,
                    offsetY: 0,
                    offsetHeight: browserVC.cardViewDefaultFrame.height - browserVC.cardView.bounds.height
                )
            } else {
                homeVC.setThumbPosition(expanded: false)
            }
            
            homeVC.setNeedsStatusBarAppearanceUpdate()
                
            newTabToolbar.transform = self.isExpanding ? CGAffineTransform(translationX: 0, y: Const.shared.toolbarHeight) : .identity
                
        }, completion: { finished in
            browserVC.isSnapshotMode = false
            browserVC.webView.scrollView.isScrollEnabled = true

            thumb?.setTab(browserVC.browserTab!)
            thumb?.clipSnapFromBottom = clipSnapFromBottom
                        
            homeVC.view.addSubview(newTabToolbar)
            newTabToolbar.isHidden = self.isExpanding
            
            if self.direction == .dismiss {
                homeVC.visibleCells.forEach { $0.isHidden = false }
                homeVC.setNeedsStatusBarAppearanceUpdate()
            }
            
            transitionContext.completeTransition(true)
        })
    }
}
