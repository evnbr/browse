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
        else {
//            typeaheadVC.textView.becomeFirstResponder() // Unclear why this is necessary
        }
        
        browserVC?.toolbar.backgroundView.alpha = 1
        let toolbarSnap = browserVC?.toolbar.snapshotView(afterScreenUpdates: isDismissing)
        if let t = toolbarSnap, let tc = browserVC?.toolbar.center {
            containerView.addSubview(t)
//            browserVC?.locationBar.isHidden = true
            browserVC?.backButton.isHidden = true
            browserVC?.tabButton.isHidden = true
            
            t.center = tc
            if !isExpanding {
                t.center.y -= typeaheadVC.kbHeightConstraint.constant - 24
            }
        }
        
        browserVC?.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        typeaheadVC.suggestHeightConstraint.constant = isExpanding ? typeaheadVC.suggestionHeight : 12
        typeaheadVC.kbHeightConstraint.constant = isExpanding
            ? typeaheadVC.keyboardHeight
            : (browserVC != nil ? 0 : -48) // room for indicator
        
        // note order, prevent both from being enabled
        if isExpanding {
            typeaheadVC.collapsedTextHeight.isActive = false
            typeaheadVC.textHeightConstraint.isActive = true
        }
        else {
            typeaheadVC.textHeightConstraint.isActive = false
            typeaheadVC.collapsedTextHeight.isActive = true
        }
        
        UIView.animate(
            withDuration: 0.2,
            animations: {
                typeaheadVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
        })

        
        UIView.animate(
            withDuration: 0.35,
            animations: {
                typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.blur.alpha = self.isExpanding ? 1 : 0
        })
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                typeaheadVC.view.layoutIfNeeded()
                typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.cancel.alpha = self.isExpanding ? 1 : 0

                if self.isDismissing {
                    typeaheadVC.textView.resignFirstResponder()
                }
                
                if let t = toolbarSnap, let tc = browserVC?.toolbar.center {
                    t.center = tc
                    if self.isExpanding {
                        t.center.y -= typeaheadVC.keyboardHeight - 24
                    }
                    t.alpha = self.isExpanding ? 0 : 1
                }
        }, completion: { _ in
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            toolbarSnap?.removeFromSuperview()
//            browserVC?.locationBar.isHidden = false
            browserVC?.backButton.isHidden = false
            browserVC?.tabButton.isHidden = false
            browserVC?.toolbar.backgroundView.alpha = 1

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    

}
