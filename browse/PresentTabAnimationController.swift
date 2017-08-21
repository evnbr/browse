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
extension UIView
{
    func addCornerRadiusAnimation(to: CGFloat, duration: CFTimeInterval)
    {
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
        
        let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        
        let containerView = transitionContext.containerView
        
        let homeNav = (isExpanding ? fromVC : toVC) as! UINavigationController
        let browserVC = (isExpanding ? toVC : fromVC) as! BrowserViewController
        
        let homeVC = homeNav.topViewController as! HomeViewController
        
        let thumb = homeVC.thumb(forTab: browserVC.browserTab!)
        thumb?.isHidden = true

        if direction == .present {
            browserVC.resetSizes(withKeyboard: browserVC.isBlank)
        }
        
        if isExpanding {
            containerView.addSubview(browserVC.view)
        }
        
        
        browserVC.updateSnapshot()
        
        let prevTransform = homeNav.view.transform
        homeNav.view.transform = .identity // HACK reset to identity so we can get frame
        
        
        var thumbFrame : CGRect
        var duration = 0.4
        
        if thumb != nil {
            // must be after toVC is added
            thumbFrame = containerView.convert(thumb!.frame, from: thumb?.superview)
        }
        else {
            // animate from bottom
            let y = (homeVC.navigationController?.view.frame.height)!
            thumbFrame = CGRect(origin: CGPoint(x: 0, y: y), size: homeVC.thumbSize)
            thumbFrame.size.height = 40
            duration = 0.5
        }
        
        let transitioningThumb = TabThumbnail(frame: thumbFrame)
        transitioningThumb.setTab(browserVC.browserTab!)
        
        let expandedFrame = browserVC.cardView.frame
        
//        browserVC.cardView.frame = isExpanding ? thumbFrame : expandedFrame // NOTE: Would remove need for transitioningthumb
        
        transitioningThumb.frame = isExpanding ? thumbFrame : expandedFrame
        transitioningThumb.isExpanded = !isExpanding
        transitioningThumb.backgroundColor = browserVC.statusBar.backgroundColor
        if !isExpanding {
            // continue from wherever cardview left off
            transitioningThumb.layer.cornerRadius = browserVC.cardView.layer.cornerRadius
        }
        else {
            // reset cardview radius
            browserVC.cardView.layer.cornerRadius = CARD_RADIUS
        }
        
        homeNav.view.transform = self.isExpanding
            ? .identity
            : prevTransform
        
        browserVC.cardView.isHidden = true
        
        let END_ALPHA : CGFloat = 0.0

//        homeNav.view.alpha = isExpanding ? 1.0 : END_ALPHA
        
        var toolbarEndY = browserVC.cardView.frame.height
        if isExpanding {
            browserVC.toolbar.alpha = 0.0
            if browserVC.isBlank {
                // keyboard
                browserVC.toolbar.frame.origin.y = max(
                    expandedFrame.height + 100,
                    thumbFrame.origin.y + thumbFrame.height
                )
            }
            else {
                browserVC.toolbar.frame.origin.y = browserVC.cardView.frame.height - 40
            }
//            browserVC.toolbar.frame.origin.y = homeVC.view.frame.height
//            browserVC.toolbar.frame.origin.y = thumbFrame.origin.y + thumbFrame.height
        } else {
            toolbarEndY = browserVC.cardViewDefaultFrame.height - 20
        }
        
        containerView.addSubview(transitioningThumb)
        containerView.bringSubview(toFront: transitioningThumb)
        
        // Hack to keep thumbnails from intersecting toolbar
        let newTabToolbar = homeVC.toolbar!
        containerView.addSubview(newTabToolbar)
        containerView.bringSubview(toFront: newTabToolbar)
        
        newTabToolbar.isHidden = false
        newTabToolbar.transform = isExpanding ? .identity : CGAffineTransform(translationX: 0, y: 12)
        newTabToolbar.alpha = self.isExpanding ? 1 : 0
        
        UIView.animate(
            withDuration: duration,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: .allowUserInteraction,
            animations: {
                
//            browserVC.cardView.frame = self.isExpanding ? expandedFrame : thumbFrame
            transitioningThumb.frame = self.isExpanding ? expandedFrame : thumbFrame
            transitioningThumb.isExpanded = self.isExpanding
            
            homeNav.view.alpha = self.isExpanding ? END_ALPHA : 1.0
            homeNav.view.transform = self.isExpanding
                ? CGAffineTransform(scaleX: PRESENT_TAB_BACK_SCALE, y: PRESENT_TAB_BACK_SCALE)
                : .identity
                
            browserVC.toolbar.alpha = self.isExpanding ? 1.0 : 0.0
            browserVC.toolbar.frame.origin.y = toolbarEndY
            
            homeVC.setNeedsStatusBarAppearanceUpdate()
                
            newTabToolbar.transform = self.isExpanding ? CGAffineTransform(translationX: 0, y: 12) : .identity
            newTabToolbar.alpha = self.isExpanding ? 0 : 1
                
        }, completion: { finished in
            
            transitionContext.completeTransition(true)
            
            browserVC.cardView.isHidden = false
            
            thumb?.setTab(browserVC.browserTab!)
            
            transitioningThumb.removeFromSuperview()
            
            homeVC.view.addSubview(newTabToolbar)
            newTabToolbar.isHidden = self.isExpanding
            
            if self.direction == .dismiss {
                thumb?.isHidden = false
                homeVC.setNeedsStatusBarAppearanceUpdate()
            }
            

        })
    }
}
