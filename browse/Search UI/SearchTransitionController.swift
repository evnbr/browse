//
//  SearchTransitionController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

let textFieldExtraYShift: CGFloat = -4
let maskExtraXShift: CGFloat = 24
let extraXShift: CGFloat = -4

let titleExtraYShift: CGFloat = -12
let titleExtraYShiftEnd: CGFloat = 71
let lockWidth: CGFloat = 19
let searchWidth: CGFloat = 22
let textFieldMargin: CGFloat = 40

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
        
        let smallSize = Const.thumbTitleFont.pointSize
        let largeSize = Const.textFieldFont.pointSize
        let scaledUp: CGFloat = largeSize / smallSize
        let scaledDown: CGFloat = smallSize / largeSize
        
        let prefix = typeaheadVC.textView.text.urlPrefix
        let prefixSize = prefix?.boundingRect(
            with: typeaheadVC.textView.bounds.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedStringKey.font: typeaheadVC.textView.font!],
            context: nil)
        let prefixWidth: CGFloat = (prefixSize?.width ?? 0)

        var maskStartSize : CGSize = titleSnap?.bounds.size ?? .zero
        maskStartSize.height = 48
        let maskStartFrame = CGRect(origin: CGPoint(x: prefixWidth + maskExtraXShift, y: 0), size: maskStartSize)
        let maskEndSize : CGSize = CGSize(width: typeaheadVC.textView.bounds.size.width, height: typeaheadVC.textHeight)
        let maskEndFrame = CGRect(origin: .zero, size: maskEndSize)

        
        if let title = titleSnap {
            containerView.addSubview(title)
        }
        var titleStartCenter = browserVC?.toolbar.center ?? .zero
        var titleEndCenter = titleStartCenter
        titleStartCenter.y += titleExtraYShift
        
        let hasSearch = browserVC?.toolbar.isSearch ?? false
        let hasLock = (browserVC?.toolbar.isSecure ?? false) && !hasSearch
        let titleWidth = (titleSnap?.bounds.width ?? 0) * scaledUp
        let textFieldWidth = (browserVC?.toolbar.bounds.width ?? UIScreen.main.bounds.width) - textFieldMargin
        let titleToTextDist = (textFieldWidth - titleWidth ) / 2
        let roomForLockShift: CGFloat = (hasLock ? lockWidth : 0) + (hasSearch ? searchWidth : 0)
        let titleHorizontalShift : CGFloat = titleToTextDist + roomForLockShift - prefixWidth + extraXShift
        titleEndCenter.x -= titleHorizontalShift
        titleEndCenter.y -= typeaheadVC.textHeightConstraint.constant
        titleEndCenter.y += titleExtraYShiftEnd
        if isDismissing {
            titleEndCenter.y -= max(typeaheadVC.kbHeightConstraint.constant, 0)
        }
        else if showKeyboard {
            titleEndCenter.y -= typeaheadVC.keyboard.height
        }

        titleSnap?.center = isExpanding ? titleStartCenter : titleEndCenter

        browserVC?.toolbar.backgroundView.alpha = 1
        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        
        typeaheadVC.kbHeightConstraint.constant = isExpanding
            ? (showKeyboard ? typeaheadVC.keyboard.height : 0 )
            : 0
        typeaheadVC.contextAreaHeightConstraint.springConstant(to: isExpanding
            ? typeaheadVC.contextAreaHeight : 0)
        
        titleSnap?.scale = isExpanding ? 1 : scaledUp
        titleSnap?.alpha = isExpanding ? 1 : 0
        typeaheadVC.textView.alpha = isExpanding ? 0 : 1

        typeaheadVC.textView.transform = CGAffineTransform(scale: isExpanding ? scaledDown : 1).translatedBy(x: isExpanding ? titleHorizontalShift : 0, y: isExpanding ? textFieldExtraYShift : 0)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            typeaheadVC.dragHandle.alpha = self.isExpanding ? 1 : 0
            typeaheadVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
        })
        
        typeaheadVC.textView.mask?.frame = isExpanding ? maskStartFrame : maskEndFrame
        
        if showKeyboard && isExpanding {
            typeaheadVC.focusTextView()
        }
        
        typeaheadVC.textHeightConstraint.constant = isExpanding ? typeaheadVC.textHeight : Const.toolbarHeight
        
        func completeTransition() {
            if self.isDismissing { typeaheadVC.view.removeFromSuperview() }
            titleSnap?.removeFromSuperview()
            browserVC?.toolbar.searchField.labelHolder.isHidden = false
            browserVC?.toolbar.backgroundView.alpha = 1
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
        let completeEarly = !showKeyboard && isExpanding
        if completeEarly { completeTransition() }
        
        typeaheadVC.iconProgress = isExpanding ? 1 : 0
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                typeaheadVC.view.layoutIfNeeded()
                typeaheadVC.pageActionView.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.scrim.alpha = self.isExpanding ? 1 : 0
                typeaheadVC.textView.alpha = self.isExpanding ? 1 : 0
                titleSnap?.alpha = self.isExpanding ? 0 : 1
                
                titleSnap?.scale = self.isExpanding ? scaledUp : 1
                titleSnap?.center = self.isExpanding ? titleEndCenter : titleStartCenter
                
                typeaheadVC.textView.transform = CGAffineTransform(scale: self.isExpanding ? 1 : scaledDown ).translatedBy(x: self.isExpanding ? 0 : titleHorizontalShift, y: self.isExpanding ? 0 : textFieldExtraYShift)

                typeaheadVC.textView.mask?.frame = self.isExpanding ? maskEndFrame : maskStartFrame

                if self.isDismissing { typeaheadVC.textView.resignFirstResponder() }
                
        }, completion: { _ in
            if !completeEarly { completeTransition() }
        })
    }
    

}
