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
//        let browserVC = (isExpanding ? fromVC : toVC) as! BrowserViewController

        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }
        
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        let anim = typeaheadVC.kbHeightConstraint.springConstant(to: self.isExpanding
            ? -typeaheadVC.keyboardHeight
            : 200)
        anim?.springBounciness = 2
        anim?.springSpeed = 6
        
        UIView.animate(withDuration: 0.3, animations: {
            typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
        }) { (_) in
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
    }
    

}
