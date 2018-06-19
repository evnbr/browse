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

typealias SearchTransitionCompletionBlock = () -> Void


class SearchTransitionController: NSObject {
    
    var direction : CustomAnimationDirection!
    var isExpanding  : Bool { return direction == .present }
    var isDismissing : Bool { return direction == .dismiss }
    
    var showKeyboard : Bool = true
    var isPreExpanded: Bool = false
    
    func animateTransition(searchVC: SearchViewController, browserVC: BrowserViewController, completion: SearchTransitionCompletionBlock? ) {
        browserVC.toolbar.backgroundView.alpha = 1
        let titleSnap = browserVC.toolbar.searchField.labelHolder.snapshotView(afterScreenUpdates: false) // TODO doesnt work if hidden
        browserVC.toolbar.searchField.labelHolder.isHidden = true
        
        print("start transition")
        searchVC.isTransitioning = true
        
        let smallSize = Const.thumbTitleFont.pointSize
        let largeSize = Const.textFieldFont.pointSize
        let scaledUp: CGFloat = largeSize / smallSize
        let scaledDown: CGFloat = smallSize / largeSize
        
        let prefix = searchVC.textView.text.urlPrefix
        let prefixSize = prefix?.boundingRect(
            with: searchVC.textView.bounds.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedStringKey.font: searchVC.textView.font!],
            context: nil)
        let prefixWidth: CGFloat = (prefixSize?.width ?? 0)
        
        var maskStartSize : CGSize = titleSnap?.bounds.size ?? .zero
        maskStartSize.height = 48
        let maskStartFrame = CGRect(origin: CGPoint(x: prefixWidth + maskExtraXShift, y: 0), size: maskStartSize)
        let maskEndSize : CGSize = CGSize(width: searchVC.textView.bounds.size.width, height: searchVC.textHeight)
        let maskEndFrame = CGRect(origin: .zero, size: maskEndSize)
        
        if let title = titleSnap {
            searchVC.view.addSubview(title)
        }
        var titleStartCenter = browserVC.toolbar.center
        var titleEndCenter = titleStartCenter
        titleStartCenter.y += titleExtraYShift
        
        let hasSearch = browserVC.toolbar.isSearch
        let hasLock = (browserVC.toolbar.isSecure) && !hasSearch
        let titleWidth = (titleSnap?.bounds.width ?? 0) * scaledUp
        let textFieldWidth = (browserVC.toolbar.bounds.width) - textFieldMargin
        let titleToTextDist = (textFieldWidth - titleWidth ) / 2
        let roomForLockShift: CGFloat = (hasLock ? lockWidth : 0) + (hasSearch ? searchWidth : 0)
        let titleHorizontalShift : CGFloat = titleToTextDist + roomForLockShift - prefixWidth + extraXShift
        titleEndCenter.x -= titleHorizontalShift
        titleEndCenter.y -= searchVC.textHeightConstraint.constant
        titleEndCenter.y += titleExtraYShiftEnd
        if isDismissing {
            titleEndCenter.y -= max(searchVC.kbHeightConstraint.constant, 0)
        }
        else if showKeyboard {
            titleEndCenter.y -= searchVC.keyboard.height
        }
        
        titleSnap?.center = isExpanding ? titleStartCenter : titleEndCenter
        
        browserVC.toolbar.backgroundView.alpha = 1
        //        typeaheadVC.scrim.alpha = isExpanding ? 0 : 1
        
        searchVC.kbHeightConstraint.constant = isExpanding
            ? (showKeyboard ? searchVC.keyboard.height : 0 )
            : 0
        searchVC.contextAreaHeightConstraint.springConstant(to: isExpanding
            ? searchVC.contextAreaHeight : 0)
        
        titleSnap?.scale = isExpanding ? 1 : scaledUp
        titleSnap?.alpha = isExpanding ? 1 : 0
        searchVC.textView.alpha = isExpanding ? 0 : 1
        
        searchVC.textView.transform = CGAffineTransform(scale: isExpanding ? scaledDown : 1).translatedBy(x: isExpanding ? titleHorizontalShift : 0, y: isExpanding ? textFieldExtraYShift : 0)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            searchVC.dragHandle.alpha = self.isExpanding ? 1 : 0
            searchVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
        })
        
        searchVC.textView.mask?.frame = isExpanding ? maskStartFrame : maskEndFrame
        
        if showKeyboard && isExpanding {
            searchVC.focusTextView()
        }
        
        searchVC.textHeightConstraint.constant = isExpanding ? searchVC.textHeight : Const.toolbarHeight
        
        func completeTransition() {
            if self.isDismissing { searchVC.view.removeFromSuperview() }
            searchVC.isTransitioning = false
            titleSnap?.removeFromSuperview()
            browserVC.toolbar.searchField.labelHolder.isHidden = false
            browserVC.toolbar.backgroundView.alpha = 1
            print("end transition")
            completion?()
        }
        
        let completeEarly = !showKeyboard && isExpanding && !isPreExpanded
        print("complete early: \(completeEarly)")
        if completeEarly { completeTransition() }
        
        searchVC.iconEntranceProgress = isExpanding ? 1 : 0
        searchVC.view.center = browserVC.view.center
        
        UIView.animate(
            withDuration: isPreExpanded ? 2.0 : 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                searchVC.view.layoutIfNeeded()
                searchVC.pageActionView.alpha = self.isExpanding ? 1 : 0
                searchVC.scrim.alpha = 0//self.isExpanding ? 1 : 0
                searchVC.textView.alpha = self.isExpanding ? 1 : 0
                titleSnap?.alpha = self.isExpanding ? 0 : 1
                
                titleSnap?.scale = self.isExpanding ? scaledUp : 1
                titleSnap?.center = self.isExpanding ? titleEndCenter : titleStartCenter
                
                searchVC.textView.transform = CGAffineTransform(scale: self.isExpanding ? 1 : scaledDown ).translatedBy(x: self.isExpanding ? 0 : titleHorizontalShift, y: self.isExpanding ? 0 : textFieldExtraYShift)
                
                searchVC.textView.mask?.frame = self.isExpanding ? maskEndFrame : maskStartFrame
                
                if self.isDismissing { searchVC.textView.resignFirstResponder() }
                
        }, completion: { _ in
            if !completeEarly { completeTransition() }
        })
    }
    
}

extension SearchTransitionController: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 2.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let typeaheadVC = (isExpanding ? toVC : fromVC) as! SearchViewController
        let browserVC = (isExpanding ? fromVC : toVC) as! BrowserViewController
        
        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }
        
        self.animateTransition(searchVC: typeaheadVC, browserVC: browserVC) {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        
    }
}
