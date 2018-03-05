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
        
        browserVC?.toolbar.backgroundView.alpha = 1
        let titleSnap = browserVC?.locationBar.labelHolder.snapshotView(afterScreenUpdates: isDismissing)
        browserVC?.locationBar.labelHolder.isHidden = true
        let toolbarSnap = browserVC?.toolbar.snapshotView(afterScreenUpdates: isDismissing)
        if let tbar = toolbarSnap, let tc = browserVC?.toolbar.center {
            containerView.addSubview(tbar)
            browserVC?.backButton.isHidden = true
            browserVC?.tabButton.isHidden = true
            
            tbar.center = tc
            if isDismissing {
                tbar.center.y -= typeaheadVC.kbHeightConstraint.constant
                tbar.center.y -= typeaheadVC.toolbarBottomMargin.constant
//                tbar.center.y -= typeaheadVC.textHeightConstraint.constant - 60
            }
        }
        
        if let title = titleSnap {
            containerView.addSubview(title)
        }
        var startCenter = browserVC?.toolbar.center ?? .zero
        startCenter.y -= 12
        var endCenter = startCenter
//        let titleHorizontalShift : CGFloat = 60 //(browserVC!.toolbar.bounds.width - titleSnap!.bounds.width) / 3
        let titleHorizontalShift : CGFloat = (browserVC!.toolbar.bounds.width - titleSnap!.bounds.width - 40) / 2
        endCenter.x -= titleHorizontalShift
        endCenter.y -= typeaheadVC.textHeightConstraint.constant - 70
        if isDismissing {
            endCenter.y -= typeaheadVC.kbHeightConstraint.constant
            endCenter.y -= typeaheadVC.toolbarBottomMargin.constant
        }
        else {
            endCenter.y -= typeaheadVC.keyboardHeight
            endCenter.y -= KB_MARGIN
        }

        titleSnap?.center = isExpanding ? startCenter : endCenter

        
        browserVC?.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        typeaheadVC.toolbarBottomMargin.constant = isExpanding ? KB_MARGIN : SPACE_FOR_INDICATOR
        typeaheadVC.suggestHeightConstraint.constant = isExpanding ? typeaheadVC.suggestionHeight : 0
        typeaheadVC.kbHeightConstraint.constant = isExpanding ? typeaheadVC.keyboardHeight : 0 // room for indicator
        
        titleSnap?.scale = isExpanding ? 1 : 1.15
        titleSnap?.alpha = isExpanding ? 1 : 0
        toolbarSnap?.alpha = isExpanding ? 1 : -1
        typeaheadVC.textView.alpha = isExpanding ? 0 : 1
        typeaheadVC.cancel.alpha = isExpanding ? -1 : 1

//        typeaheadVC.textView.scale = isExpanding ? 0.9 : 1
        typeaheadVC.textView.transform = CGAffineTransform(translationX: self.isExpanding ? titleHorizontalShift : 0, y: 0)
        typeaheadVC.cancel.transform = CGAffineTransform(translationX: self.isExpanding ? titleHorizontalShift : 0, y: 0)
        if isDismissing { toolbarSnap?.center.x -= titleHorizontalShift * 0.5 }

        typeaheadVC.textHeightConstraint.constant = isExpanding ? typeaheadVC.textHeight : 40

        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            typeaheadVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
            toolbarSnap?.alpha = self.isExpanding ? 0 : 1

            titleSnap?.scale = self.isExpanding ? 1.15 : 1
        })

        UIView.animate(withDuration: 0.35) {
            typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
            
            titleSnap?.alpha = self.isExpanding ? 0 : 1
            typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
        }
        
        
        // Crossfade textview and title
//        UIView.animate(withDuration: 0.2, delay: isExpanding ? 0 : 0.3, options: .curveEaseInOut, animations: {
//            titleSnap?.alpha = self.isExpanding ? 0 : 1
//        })
//        UIView.animate(withDuration: 0.2, delay: isExpanding ? 0.3 : 0, options: .curveEaseInOut, animations: {
//            typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
//        })
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                typeaheadVC.view.layoutIfNeeded()
//                typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.cancel.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
                
                titleSnap?.center = self.isExpanding ? endCenter : startCenter
                
                if !self.isDismissing { toolbarSnap?.center.x -= titleHorizontalShift * 0.5 }
                typeaheadVC.textView.transform = CGAffineTransform(translationX: self.isExpanding ? 0 : titleHorizontalShift, y: 0)
                typeaheadVC.cancel.transform = CGAffineTransform(translationX: self.isExpanding ? 0 : titleHorizontalShift, y: 0)

                
                if self.isDismissing {
                    typeaheadVC.textView.resignFirstResponder()
                }
                
                if let tbar = toolbarSnap, let tc = browserVC?.toolbar.center {
                    tbar.center = tc
                    if self.isExpanding {
                        tbar.center.y -= typeaheadVC.keyboardHeight - 24
                    }
                    tbar.alpha = self.isExpanding ? 0 : 1
                }
        }, completion: { _ in
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            toolbarSnap?.removeFromSuperview()
            titleSnap?.removeFromSuperview()
            browserVC?.locationBar.labelHolder.isHidden = false

//            browserVC?.locationBar.isHidden = false
            browserVC?.backButton.isHidden = false
            browserVC?.tabButton.isHidden = false
            browserVC?.toolbar.backgroundView.alpha = 1

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    

}
