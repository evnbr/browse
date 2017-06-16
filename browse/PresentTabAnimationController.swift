//
//  CustomPresentAnimationController.swift
//  browse
//
//  Created by Evan Brooks on 5/31/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  Based on http://www.appcoda.com/custom-view-controller-transitions-tutorial/
//  https://www.raywenderlich.com/146692/ios-animation-tutorial-custom-view-controller-presentation-transitions-2
//
//  TODO: the homeVC should present the webVC, its backwards now

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
        return 0.6
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        
        let containerView = transitionContext.containerView
        
        let homeNav = isExpanding ? fromVC : toVC
        let webVC = (isExpanding ? toVC : fromVC) as! WebViewController
        
        let homeVC = (homeNav as! UINavigationController).topViewController as! HomeViewController
        
//        let thumb = homeVC.thumb!
        let thumb = homeVC.thumb(forTab: webVC)
        
        thumb?.isHidden = true

        if direction == .present {
            webVC.view.transform = .identity
            webVC.cardView.frame.origin = .zero
        }
        
        let snapshot : UIView = webVC.cardView.snapshotView(afterScreenUpdates: true)!
//        snapshot.clipsToBounds = true
        let thumbFrame = containerView.convert(thumb!.frame, from: thumb?.superview) // must be after toVC is added

        let transitioningThumb = TabThumbnail(frame: thumbFrame, tab: nil, onTap: nil)
        
        transitioningThumb.frame = isExpanding ? thumbFrame : webVC.cardView.frame
        
        transitioningThumb.layer.cornerRadius = isExpanding ? 5.0 : 8.0

        transitioningThumb.setSnapshot(snapshot)

        webVC.cardView.isHidden = true
        
        homeNav.view.alpha = isExpanding ? 1.0 : 0.3
        if isExpanding { webVC.toolbar.alpha = 0.0 }

        containerView.addSubview(transitioningThumb)
        containerView.bringSubview(toFront: transitioningThumb)

        if isExpanding {
            containerView.addSubview(webVC.view)
        }
        
        
        transitioningThumb.addCornerRadiusAnimation(
            to: self.isExpanding ? 8.0 : 5.0,
            duration: transitionDuration(using: transitionContext)
        )
        
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [.curveLinear], animations: {
            
            transitioningThumb.frame = self.isExpanding ? webVC.cardView.frame : thumbFrame

            homeNav.view.alpha = self.isExpanding ? 0.3 : 1.0
            webVC.toolbar.alpha = self.isExpanding ? 1.0 : 0.0
            homeVC.setNeedsStatusBarAppearanceUpdate()

        }, completion: { finished in
            transitionContext.completeTransition(true)
            webVC.cardView.isHidden = false
//            snapshot.removeFromSuperview()
            thumb?.setSnapshot(snapshot)
            transitioningThumb.removeFromSuperview()
            
            if self.direction == .dismiss {
                thumb?.isHidden = false
                homeVC.setNeedsStatusBarAppearanceUpdate()
            }
            

        })
    }
}
