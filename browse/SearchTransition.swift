//
//  SearchTransition.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

// https://code.tutsplus.com/tutorials/how-to-create-custom-view-controller-transitions-and-animations--cms-25716

enum TransitionType {
    case Presenting, Dismissing
}

class AnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    var duration: TimeInterval
    var isPresenting: Bool
    var originFrame: CGRect
    
    init(withDuration duration: TimeInterval, forTransitionType type: TransitionType, originFrame: CGRect) {
        self.duration = duration
        self.isPresenting = type == .Presenting
        self.originFrame = originFrame
        
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        let fromView = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!.view
        let toView = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!.view
        
        let detailView = self.isPresenting ? toView : fromView
//        let rootView = self.isPresenting ? fromView : toView
        
        if self.isPresenting {
            containerView.addSubview(toView!)
        }
//        else {
//            containerView.insertSubview(toView!, belowSubview: fromView!)
//        }
        
        let shiftY = self.originFrame.origin.y - 200
        let openedTransform = CGAffineTransform.identity
        let closedTransform = CGAffineTransform.identity.translatedBy(x: 0, y: shiftY)
//        let shiftedMain = CGAffineTransform.identity.translatedBy(x: 0, y: -shiftY)
        
        for view in (detailView?.subviews)! {
            if view.tag == SearchViewController.PANEL_TAG {
                if self.isPresenting {
                    view.transform = closedTransform
                }
                for sv in view.subviews {
                    sv.alpha = isPresenting ? 0.0 : 1.0
                }
                
            }
            else {
                view.alpha = isPresenting ? 0.0 : 1.0

            }
        }

        UIView.animate(withDuration: self.duration, animations: {
//            rootView?.transform = self.isPresenting ? shiftedMain : CGAffineTransform.identity
            
            for view in (detailView?.subviews)! {
                if view.tag == SearchViewController.PANEL_TAG {
                    view.transform = self.isPresenting ? openedTransform : closedTransform
                    for sv in view.subviews {
                        sv.alpha = self.isPresenting ? 1.0 : 0.0
                    }
                }
                else {
                    view.alpha = self.isPresenting ? 1.0 : 0.0
                }
            }
        }) { (completed: Bool) -> Void in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension SiteViewController: UIViewControllerTransitioningDelegate {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.transitioningDelegate = self
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AnimationController(withDuration: 0.4, forTransitionType: .Presenting, originFrame: self.toolbar.frame)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AnimationController(withDuration: 0.4, forTransitionType: .Dismissing, originFrame: self.toolbar.frame)
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return self.interactionController
    }

}
