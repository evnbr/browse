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
        let browserVC = (isExpanding ? fromVC : toVC) as? BrowserViewController

        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }
        
        let toolbarSnap = browserVC?.toolbar.snapshotView(afterScreenUpdates: false)
        if let t = toolbarSnap, let tc = browserVC?.toolbar.center {
            containerView.addSubview(t)
            browserVC?.toolbar.isHidden = true // TODO: Hide contents, not background
            t.center = tc
            if !isExpanding { t.center.y -= typeaheadVC.keyboardHeight }
        }
        
        browserVC?.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        typeaheadVC.suggestHeightConstraint.constant = isExpanding ? typeaheadVC.suggestionHeight : 12
        typeaheadVC.kbHeightConstraint.constant = isExpanding
            ? typeaheadVC.keyboardHeight
            : (browserVC != nil ? 24 : -48) // room for indicator
        
        // note order, prevent both from being enabled
        if isExpanding {
            typeaheadVC.collapsedTextHeight.isActive = false
            typeaheadVC.textHeight.isActive = true
        }
        else {
            typeaheadVC.textHeight.isActive = false
            typeaheadVC.collapsedTextHeight.isActive = true
        }
        
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

                if self.isDismissing {
                    typeaheadVC.textView.resignFirstResponder()
                }
                
                if let t = toolbarSnap, let tc = browserVC?.toolbar.center {
                    t.center = tc
                    if self.isExpanding { t.center.y -= typeaheadVC.keyboardHeight }
                    t.alpha = self.isExpanding ? 0 : 1
                }
        }, completion: { _ in
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            toolbarSnap?.removeFromSuperview()
            browserVC?.toolbar.isHidden = false
            browserVC?.toolbar.backgroundView.alpha = 1

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    

}
