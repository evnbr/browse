//
//  TypeaheadAnimationController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class TypeaheadAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    
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
        
        let typeaheadVC = (isExpanding ? toVC : fromVC) as! TypeaheadViewController
        let browserVC = (isExpanding ? fromVC : toVC) as! BrowserViewController

        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }
        
        let toolbarSnap = browserVC.toolbar.snapshotView(afterScreenUpdates: false)
        if let t = toolbarSnap {
            containerView.addSubview(t)
            t.center = browserVC.toolbar.center
            if !isExpanding { t.center.y -= typeaheadVC.keyboardHeight }
        }
        
        browserVC.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        typeaheadVC.suggestHeightConstraint.constant = self.isExpanding ? typeaheadVC.suggestionHeight : 12
        typeaheadVC.kbHeightConstraint.constant = self.isExpanding
            ? -typeaheadVC.keyboardHeight - 12
            : -24 // room for indicator
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                typeaheadVC.view.layoutIfNeeded()
                typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.cancel.alpha = self.isExpanding ? 1 : 0

                if let t = toolbarSnap {
                    t.center = browserVC.toolbar.center
                    if self.isExpanding { t.center.y -= typeaheadVC.keyboardHeight }
                    t.alpha = self.isExpanding ? 0 : 1
                }
        }, completion: { _ in
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            toolbarSnap?.removeFromSuperview()
            browserVC.toolbar.backgroundView.alpha = 1

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    

}
