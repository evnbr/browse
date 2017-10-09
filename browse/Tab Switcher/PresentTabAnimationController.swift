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

// https://stackoverflow.com/questions/5948167/uiview-animatewithduration-doesnt-animate-cornerradius-variation
extension UIView {
    func addCornerRadiusAnimation(to: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath:"cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.fromValue = self.layer.cornerRadius
        animation.toValue = to
        animation.duration = duration
        self.layer.add(animation, forKey: "cornerRadius")
        self.layer.cornerRadius = to
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
            for cell in homeVC.visibleCellsBelow {
                cell.frame.origin.y = containerView.frame.height
            }
        }
        
        if !self.isExpanding {
            browserVC.updateSnapshot()
        }
        
        browserVC.isSnapshotMode = true
        browserVC.hasStatusbarOffset = !self.isExpanding
        
        let prevTransform = homeNav.view.transform
        homeNav.view.transform = .identity // HACK reset to identity so we can get frame
        
        
        var thumbFrame : CGRect
        
        if thumb != nil {
            // must be after toVC is added
            thumbFrame = containerView.convert(thumb!.frame, from: thumb?.superview)
            thumbFrame.origin.y -= homeNav.view.frame.origin.y
            thumbFrame.origin.x -= homeNav.view.frame.origin.x
        }
        else {
            // animate from bottom
            let y = (homeVC.navigationController?.view.frame.height)!
            thumbFrame = CGRect(origin: CGPoint(x: 0, y: y), size: homeVC.thumbSize)
            thumbFrame.size.height = 40
        }
        
        let expandedFrame = browserVC.cardView.frame
        
        homeNav.view.transform = self.isExpanding
            ? .identity
            : prevTransform
        
        let END_ALPHA : CGFloat = 0.0
        
        
        browserVC.cardView.frame = isExpanding ? thumbFrame : expandedFrame
        
        
        let cellsMovedToFront = homeVC.visibleCellsBelow
        if let cv = homeVC.collectionView {
            for cell in cellsMovedToFront {
                containerView.addSubview(cell)
                if self.isExpanding {
                    let ip = cv.indexPath(for: cell)!
                    let intendedFrame = cv.layoutAttributesForItem(at: ip)!.frame
                    let convertedFrame = containerView.convert(intendedFrame, from: cv)
                    cell.frame = convertedFrame
                }
            }
        }
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
                
            browserVC.cardView.frame = self.isExpanding ? expandedFrame : thumbFrame
                
            homeNav.view.frame.origin = CGPoint.zero
            homeNav.view.alpha = self.isExpanding ? END_ALPHA : 1.0
            homeNav.view.transform = self.isExpanding
                ? CGAffineTransform(scaleX: PRESENT_TAB_BACK_SCALE, y: PRESENT_TAB_BACK_SCALE)
                : .identity
                
            if self.isExpanding {
                homeVC.setCollapsed(true)
                for cell in homeVC.visibleCellsBelow {
                    cell.frame.origin.y = containerView.frame.height
                }
            }
            else {
                if let cv = homeVC.collectionView {
                    for cell in homeVC.visibleCellsAbove {
                        let ip = cv.indexPath(for: cell)!
                        let intendedFrame = cv.layoutAttributesForItem(at: ip)!.frame
                        cell.frame = intendedFrame
                    }
                    for cell in homeVC.visibleCellsBelow {
                        let ip = cv.indexPath(for: cell)!
                        let intendedFrame = cv.layoutAttributesForItem(at: ip)!.frame
                        let convertedFrame = containerView.convert(intendedFrame, from: cv)
                        cell.frame = convertedFrame
                    }
                }
            }
                
            browserVC.hasStatusbarOffset = self.isExpanding
            browserVC.cardView.layer.cornerRadius = self.isExpanding ? Const.shared.cardRadius : Const.shared.thumbRadius
            
            homeVC.setNeedsStatusBarAppearanceUpdate()
                
            newTabToolbar.transform = self.isExpanding ? CGAffineTransform(translationX: 0, y: Const.shared.toolbarHeight) : .identity
                
        }, completion: { finished in
            browserVC.isSnapshotMode = false
            
            thumb?.setTab(browserVC.browserTab!)
            
            for cell in cellsMovedToFront {
                cell.frame = homeVC.collectionView!.convert(cell.frame, from: cell.superview)
                homeVC.collectionView?.addSubview(cell)
            }
            homeVC.setCollapsed(self.isExpanding)
            
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
