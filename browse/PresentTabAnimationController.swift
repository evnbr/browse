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
        let webVC = isExpanding ? toVC : fromVC
        
        let homeVC = (homeNav as! UINavigationController).topViewController as! HomeViewController
        let thumb = homeVC.thumb!
        thumb.isHidden = true

        let snapshot : UIView = webVC.view.snapshotView(afterScreenUpdates: true)!
        snapshot.clipsToBounds = true
        snapshot.layer.cornerRadius = isExpanding ? 5.0 : 0.0

        webVC.view.isHidden = true
        
        homeNav.view.alpha = isExpanding ? 1.0 : 0.0

        containerView.addSubview(snapshot)
        
        if isExpanding {
            containerView.addSubview(webVC.view)
        }
        
        let thumbFrame = containerView.convert(thumb.frame, from: thumb.superview) // must be after toVC is added

        snapshot.frame = isExpanding ? thumbFrame : webVC.view.frame
        
        containerView.bringSubview(toFront: snapshot)
        
        
        snapshot.addCornerRadiusAnimation(
            to: self.isExpanding ? 0.0 : 5.0,
            duration: transitionDuration(using: transitionContext)
        )
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
            
            snapshot.frame = self.isExpanding ? webVC.view.frame : thumbFrame

            homeNav.view.alpha = self.isExpanding ? 0.0 : 1.0
            webVC.setNeedsStatusBarAppearanceUpdate()

        }, completion: { finished in
            transitionContext.completeTransition(true)
            webVC.view.isHidden = false
            snapshot.removeFromSuperview()
            thumb.isHidden = false
        })
    }
}
