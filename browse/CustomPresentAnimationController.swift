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

class CustomPresentAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.7
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        
        let containerView = transitionContext.containerView
        
        let bookmarksVC = (toViewController as! UINavigationController).topViewController as! BookmarksViewController
        let thumb = bookmarksVC.thumb!
        thumb.isHidden = true

        let snapshot : UIView = fromViewController.view.snapshotView(afterScreenUpdates: true)!
        fromViewController.view.isHidden = true
        
        toViewController.view.alpha = 0.0

        containerView.addSubview(snapshot)
        containerView.addSubview(toViewController.view)
        
        let thumbFrame = containerView.convert(thumb.frame, from: thumb.superview) // must be after toVC is added

        containerView.bringSubview(toFront: snapshot)
        
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
            
            snapshot.frame = thumbFrame
            toViewController.view.alpha = 1.0
            
        }, completion: { finished in
            transitionContext.completeTransition(true)
            fromViewController.view.isHidden = false
            snapshot.removeFromSuperview()
            thumb.isHidden = false
        })
    }
}
