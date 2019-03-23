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
    
    var direction: CustomAnimationDirection!
    var velocity: CGPoint = .zero
    var isExpanding: Bool { return direction == .present }
    var isDismissing: Bool { return direction == .dismiss }
    
    var showKeyboard: Bool = true
    var isPreExpanded: Bool = false
    
    // swiftlint:disable:next function_body_length
    func animateTransition(
        searchVC: SearchViewController,
        browserVC: BrowserViewController,
        completion: SearchTransitionCompletionBlock? ) {
        
        if isDismissing {
            if let newText = searchVC.textView.text,
                newText.count > 0,
                newText != browserVC.displayLocation,
                newText != browserVC.editableLocation {
                // Keep draft
                searchVC.hasDraftLocation = true
                browserVC.toolbar.text = newText
                browserVC.toolbar.isSearch = false
                browserVC.toolbar.isSecure = false
            } else {
                searchVC.hasDraftLocation = false
                browserVC.updateLoadingState()
            }
            browserVC.toolbar.layoutIfNeeded()
        } else {
            searchVC.hasDraftLocation = false
        }
        
        browserVC.toolbar.backgroundView.alpha = 1
        // TODO snapshot doesnt work if hidden
        let titleSnap = browserVC.toolbar.searchField.labelHolder.snapshotView(afterScreenUpdates: false)
        
        searchVC.isTransitioning = true
        if !searchVC.isViewLoaded {
            print("no view")
            searchVC.loadViewIfNeeded()
        }

        let smallSize = Const.thumbTitleFont.pointSize
        let largeSize = Const.textFieldFont.pointSize
        let scaledUp: CGFloat = largeSize / smallSize
        let scaledDown: CGFloat = 1 //smallSize / largeSize

        let prefix = searchVC.textView.text.urlPrefix
        let prefixSize = prefix?.boundingRect(
            with: searchVC.textView.bounds.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedStringKey.font: searchVC.textView.font!],
            context: nil)
        let prefixWidth: CGFloat = (prefixSize?.width ?? 0)

        var maskStartSize: CGSize = titleSnap?.bounds.size ?? .zero
        maskStartSize.height = 48
        let maskStartFrame = CGRect(origin: CGPoint(x: prefixWidth + maskExtraXShift, y: 0), size: maskStartSize)
        let maskEndSize: CGSize = CGSize(width: searchVC.textView.bounds.size.width, height: searchVC.textHeight)
        let maskEndFrame = CGRect(origin: .zero, size: maskEndSize)

        if let title = titleSnap {
            searchVC.textViewFill.addSubview(title)
        }
        var titleStartCenter = searchVC.textView.center
        var titleEndCenter = titleStartCenter
        titleStartCenter.y += 0
        titleStartCenter.x -= 40
        
        let hasSearch = browserVC.toolbar.isSearch
        let hasLock = (browserVC.toolbar.isSecure) && !hasSearch
        let titleWidth = (titleSnap?.bounds.width ?? 0) * scaledUp
        let textFieldWidth = (browserVC.toolbar.bounds.width) - textFieldMargin
        let titleToTextDist = (textFieldWidth - titleWidth ) / 2
        let roomForLockShift: CGFloat = (hasLock ? lockWidth : 0) + (hasSearch ? searchWidth : 0)
        let titleHorizontalShift: CGFloat = titleToTextDist + roomForLockShift - prefixWidth + extraXShift
        titleEndCenter.x -= titleHorizontalShift

        titleSnap?.center = isExpanding ? titleStartCenter : titleEndCenter

        browserVC.toolbar.backgroundView.alpha = 1
        browserVC.toolbar.contentsAlpha = 0
//        searchVC.scrim.alpha = isExpanding ? 0 : 1
        if !self.isPreExpanded {
            searchVC.shadowView.alpha = isExpanding ? 0 : 1
        }

        let heightAnim = searchVC.sheetHeight.springConstant(
            to: isExpanding ? searchVC.baseSheetHeight : searchVC.minSheetHeight,
            at: -velocity.y)
        let handleAnim = searchVC.textTopMarginConstraint.springConstant(
            to: isExpanding ? SHEET_TOP_HANDLE_MARGIN : SHEET_TOP_MARGIN)
        let fieldAnim = searchVC.textHeightConstraint.springConstant(
            to: isExpanding ? searchVC.textHeight: BUTTON_HEIGHT )
        heightAnim?.springBounciness = 2
        handleAnim?.springBounciness = 2

        if isDismissing || showKeyboard {
            heightAnim?.animationDidApplyBlock = { _ in
                searchVC.updateIconInset()
            }
        } else {
            handleAnim?.animationDidApplyBlock = { _ in
                let pct = searchVC.textTopMarginConstraint.constant.progress(
                    SHEET_TOP_MARGIN,
                    SHEET_TOP_HANDLE_MARGIN)
                searchVC.iconEntranceProgress = pct
            }
        }
        
        titleSnap?.scale = isExpanding ? 1 : scaledUp
//        titleSnap?.alpha = isExpanding ? 1 : 0
        searchVC.textView.alpha = isExpanding ? 0 : 1

        searchVC.textView.transform = CGAffineTransform(scale: isExpanding ? scaledDown : 1)
            .translatedBy(
                x: isExpanding ? titleHorizontalShift : 0,
                y: isExpanding ? textFieldExtraYShift : 0)

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            searchVC.dragHandle.alpha = self.isExpanding ? 1 : 0
            searchVC.suggestionTable.alpha = self.isExpanding ? 1 : 0
        })

        searchVC.textView.mask?.frame = isExpanding ? maskStartFrame : maskEndFrame

        if showKeyboard && isExpanding {
            searchVC.focusTextView()
        }

        func completeTransition() {
            if self.isDismissing { searchVC.view.removeFromSuperview() }
            if self.isExpanding {
                //
            }
            searchVC.isTransitioning = false
            titleSnap?.removeFromSuperview()
            browserVC.toolbar.contentsAlpha = 1
            browserVC.toolbar.backgroundView.alpha = 1
            completion?()
        }

        let completeEarly = !showKeyboard && isExpanding && !isPreExpanded
        if completeEarly { completeTransition() }

//        searchVC.iconEntranceProgress = isExpanding ? 1 : 0
        searchVC.view.center = browserVC.view.center

        // Don't block touches when dismissing
//        searchVC.scrim.isUserInteractionEnabled = isExpanding
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
//                searchVC.view.layoutIfNeeded()
                searchVC.pageActionView.alpha = self.isExpanding ? 1 : 0
                
                if !self.isPreExpanded {
                    searchVC.shadowView.alpha = self.isExpanding ? 1 : 0
                }
                
                searchVC.scrim.alpha = self.isExpanding ? 1 : 0
                searchVC.textView.alpha = self.isExpanding ? 1 : 0
                titleSnap?.alpha = self.isExpanding ? 0 : 1
                titleSnap?.scale = self.isExpanding ? scaledUp : 1
                titleSnap?.center = self.isExpanding ? titleEndCenter : titleStartCenter

                searchVC.textView.transform = CGAffineTransform(scale: self.isExpanding ? 1 : scaledDown )
                    .translatedBy(
                        x: self.isExpanding ? 0 : titleHorizontalShift,
                        y: self.isExpanding ? 0 : textFieldExtraYShift)

                searchVC.textView.mask?.frame = self.isExpanding ? maskEndFrame : maskStartFrame

                if self.isDismissing {
                    searchVC.textView.resignFirstResponder()
                }
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

        guard let typeaheadVC = (isExpanding ? toVC : fromVC) as? SearchViewController,
            let browserVC = (isExpanding ? fromVC : toVC) as? BrowserViewController else { return }

        if isExpanding {
            containerView.addSubview(typeaheadVC.view)
        }

        self.animateTransition(searchVC: typeaheadVC, browserVC: browserVC) {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

    }
}
