//
//  SearchTransitionController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class SearchTransitionController: NSObject, UIViewControllerAnimatedTransitioning {
    
    var direction : CustomAnimationDirection!
    var isExpanding  : Bool { return direction == .present }
    var isDismissing : Bool { return direction == .dismiss }
    
    var showKeyboard : Bool = true

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let typeaheadVC = (isExpanding ? toVC : fromVC) as! SearchViewController
        let browserVC = (isExpanding ? fromVC : toVC) as? BrowserViewController
        let navVC = (isExpanding ? fromVC : toVC) as? UINavigationController
        let switcherVC = navVC?.topViewController as? TabSwitcherViewController // TODO simplify
        let isAnimatingFromToolbar = browserVC != nil

        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }
        
        browserVC?.toolbar.backgroundView.alpha = 1
        let titleSnap = browserVC?.toolbar.searchField.labelHolder.snapshotView(afterScreenUpdates: false) // TODO doesnt work if hidden
        browserVC?.toolbar.searchField.labelHolder.isHidden = true
        let toolbarSnap = browserVC?.toolbar.snapshotView(afterScreenUpdates: false) // TODO doesnt work if hidden
        if let tbar = toolbarSnap, let tc = browserVC?.toolbar.center {
//            containerView.addSubview(tbar)
            browserVC?.toolbar.backButton.alpha = 0
            browserVC?.toolbar.tabButton.alpha = 0

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
        
        let titleHorizontalShift : CGFloat = isAnimatingFromToolbar ? (browserVC!.toolbar.bounds.width - (titleSnap?.bounds.width ?? 0) - 70) / 2 : 0
        let cancelShiftH : CGFloat = 80
        endCenter.x -= titleHorizontalShift
        endCenter.y -= typeaheadVC.textHeightConstraint.constant - 70
        if isDismissing {
            endCenter.y -= max(typeaheadVC.kbHeightConstraint.constant, SPACE_FOR_INDICATOR)
        }
        else if showKeyboard {
            endCenter.y -= typeaheadVC.keyboardHeight
        }

        titleSnap?.center = isExpanding ? startCenter : endCenter

        browserVC?.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        
        typeaheadVC.kbHeightConstraint.constant = isExpanding && showKeyboard
            ? typeaheadVC.keyboardHeight : 0
        typeaheadVC.contextAreaHeightConstraint.springConstant(to: isExpanding
            ? typeaheadVC.contextAreaHeight : 0)
        typeaheadVC.toolbarBottomMargin.springConstant(to: isExpanding
            ? 0 : (isAnimatingFromToolbar ? SPACE_FOR_INDICATOR : -48))
        typeaheadVC.textHeightConstraint.springConstant(to: isExpanding
            ? typeaheadVC.textHeight : 40)

        titleSnap?.scale = isExpanding ? 1 : 1.15
        titleSnap?.alpha = isExpanding ? 1 : 0
        toolbarSnap?.alpha = isExpanding ? 1 : -1
        typeaheadVC.textView.alpha = isExpanding ? 0 : 1
        typeaheadVC.cancel.alpha = isExpanding ? -1 : 1

//        typeaheadVC.textView.scale = isExpanding ? 0.9 : 1
        typeaheadVC.textView.transform = CGAffineTransform(translationX: self.isExpanding ? titleHorizontalShift : 0, y: 0)
        typeaheadVC.cancel.transform = CGAffineTransform(translationX: self.isExpanding ? cancelShiftH : 0, y: 0)
        if isDismissing { toolbarSnap?.center.x -= titleHorizontalShift * 0.5 }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            typeaheadVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
            typeaheadVC.pageActionView.alpha = self.isExpanding ? 1 : 0
            toolbarSnap?.alpha = self.isExpanding ? 0 : 1

            titleSnap?.scale = self.isExpanding ? 1.15 : 1
        })

        UIView.animate(withDuration: 0.35) {
            typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
            titleSnap?.alpha = self.isExpanding ? 0 : 1
        }
        UIView.animate(withDuration: isExpanding ? 0.3 : 0.1, animations: {
            typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
        })
        
        let maskStartSize : CGSize = titleSnap?.bounds.size ?? .zero
        let maskEndSize : CGSize = CGSize(width: typeaheadVC.textView.bounds.size.width, height: typeaheadVC.textHeight)
        // TODO - disable mask at end since it won't be scrollable
        
        typeaheadVC.textView.mask?.frame.size = isExpanding ? maskStartSize : maskEndSize

//        switcherVC?.fab.scale = isExpanding ? 1 : 0.2
//        switcherVC?.fab.springScale(to: isExpanding ? 0.2 : 1)
        
        if showKeyboard && isExpanding {
            typeaheadVC.focusTextView()
        }
        
        func completeTransition() {
            if self.isDismissing {
                typeaheadVC.view.removeFromSuperview()
            }
            toolbarSnap?.removeFromSuperview()
            titleSnap?.removeFromSuperview()
            browserVC?.toolbar.searchField.labelHolder.isHidden = false
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                browserVC?.toolbar.backButton.alpha = 1
                browserVC?.toolbar.tabButton.alpha = 1
            })
            browserVC?.toolbar.backgroundView.alpha = 1
            
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        let completeEarly = !showKeyboard && isExpanding
        if completeEarly { completeTransition() }
        
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
                typeaheadVC.pageActionView.alpha = self.isExpanding ? 1 : 0

                titleSnap?.center = self.isExpanding ? endCenter : startCenter
                
                if self.isExpanding { toolbarSnap?.center.x -= titleHorizontalShift * 0.5 }
                typeaheadVC.textView.transform = CGAffineTransform(translationX: self.isExpanding ? 0 : titleHorizontalShift, y: 0)
                typeaheadVC.cancel.transform = CGAffineTransform(translationX: self.isExpanding ? 0 : cancelShiftH, y: 0)
                
                typeaheadVC.textView.mask?.frame.size = self.isExpanding ? maskEndSize : maskStartSize

                
                if self.isDismissing {
                    typeaheadVC.textView.resignFirstResponder()
                }
                
                if let tbar = toolbarSnap, let tc = browserVC?.toolbar.center {
                    tbar.center = tc
                    if self.isExpanding && self.showKeyboard {
                        tbar.center.y -= typeaheadVC.keyboardHeight - 24
                    }
                    tbar.alpha = self.isExpanding ? 0 : 1
                }
        }, completion: { _ in
            if !completeEarly { completeTransition() }
        })
    }
    

}