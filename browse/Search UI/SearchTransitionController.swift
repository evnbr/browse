//
//  SearchTransitionController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

let maskExtraXShift: CGFloat = 24
let extraXShift: CGFloat = -20

let titleExtraYShift: CGFloat = -12
let titleExtraYShiftEnd: CGFloat = 71
let lockWidth: CGFloat = 19
let searchWidth: CGFloat = 22
let textFieldMargin: CGFloat = 40

typealias SearchTransitionCompletionBlock = () -> Void

enum CustomAnimationDirection {
    case present
    case dismiss
}

class SearchTransitionController: NSObject {
    
    var direction: CustomAnimationDirection!
    var velocity: CGPoint = .zero
    var isExpanding: Bool { return direction == .present }
    var isDismissing: Bool { return direction == .dismiss }
    
    var showKeyboard: Bool = true
    var isPreExpanded: Bool = false
    
    var fontScaledUp: CGFloat {
        return Const.textFieldFont.pointSize / Const.thumbTitleFont.pointSize
    }
    var fontScaledDown: CGFloat {
        return Const.thumbTitleFont.pointSize / Const.textFieldFont.pointSize
    }
    
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
                
                if let url = URL.coercedFrom(newText) {
                    searchVC.locationLabel.text = url.displayHost
                    browserVC.toolbar.text = url.displayHost
                    browserVC.toolbar.isSearch = false
                } else {
                    searchVC.locationLabel.text = newText
                    browserVC.toolbar.text = newText
                    browserVC.toolbar.isSearch = true
                }
                browserVC.toolbar.isSecure = false
            } else {
                searchVC.hasDraftLocation = false
                browserVC.updateLoadingState()
            }
            browserVC.toolbar.layoutIfNeeded()
        } else {
            searchVC.hasDraftLocation = false
        }
        
//        browserVC.toolbar.backgroundView.alpha = 1
        // TODO snapshot doesnt work if hidden
        
        searchVC.isTransitioning = true
        if !searchVC.isViewLoaded {
            print("no view")
            searchVC.loadViewIfNeeded()
        }

        let offsets = searchVC.calculateHorizontalOffset()

        var maskStartSize: CGSize = CGSize(
            width: searchVC.locationLabel.bounds.width * 0.9,
            height: 40)
        let maskStartFrame = CGRect(origin: CGPoint(x: offsets.prefixWidth + maskExtraXShift, y: 0), size: maskStartSize)
        let maskEndSize: CGSize = CGSize(width: searchVC.textView.bounds.size.width, height: searchVC.textHeight)
        let maskEndFrame = CGRect(origin: .zero, size: maskEndSize)

        var titleStartCenter = searchVC.textView.center
        var titleEndCenter = titleStartCenter
        titleStartCenter.y += 0
        titleStartCenter.x -= 40
        
        let titleHorizontalShift = offsets.shift
        titleEndCenter.x -= titleHorizontalShift
        
//        browserVC.toolbar.backgroundView.alpha = 1
        browserVC.toolbar.contentsAlpha = 0
        if !self.isPreExpanded {
            searchVC.shadowView.alpha = isExpanding ? 0 : 1
        }

        searchVC.sheetHeight.constant = isExpanding ? searchVC.baseSheetHeight : searchVC.minSheetHeight
        searchVC.textTopMarginConstraint.constant = isExpanding ? SHEET_TOP_HANDLE_MARGIN : TOOLBAR_TOP_MARGIN
        searchVC.textViewContainerHeightConstraint.constant =
            isExpanding ? searchVC.textHeight: BUTTON_HEIGHT

        let pct = searchVC.textTopMarginConstraint.constant.progress(
                TOOLBAR_TOP_MARGIN,
                SHEET_TOP_HANDLE_MARGIN)
        
        searchVC.bottomAttachment.constant = pct.lerp(SHEET_TOP_HANDLE_MARGIN, 0)
        searchVC.labelCenterConstraint.constant = pct.lerp(0, -titleHorizontalShift)
        searchVC.textCenterConstraint.constant = pct.lerp(titleHorizontalShift, 0)
        
        if showKeyboard && isExpanding {
            searchVC.focusTextView()
        }

        func completeTransition() {
            if self.isDismissing { searchVC.view.removeFromSuperview() }
            if self.isExpanding {
                //
            }
            searchVC.isTransitioning = false
            browserVC.toolbar.contentsAlpha = 1
//            browserVC.toolbar.backgroundView.alpha = 1
            completion?()
        }

        let completeEarly = !showKeyboard && isExpanding && !isPreExpanded
        if completeEarly { completeTransition() }

        searchVC.view.center = browserVC.view.center
        
        let fieldColor = searchVC.contentView.tintColor!.isLight ? UIColor.darkField : UIColor.lightField
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.0,
            options: [.curveLinear],
            animations: {
                searchVC.textView.alpha = pct.lerp(0, 1)
                searchVC.locationLabel.alpha = pct.lerp(1, 0)
                searchVC.iconEntranceProgress = pct
                searchVC.dragHandle.alpha = pct
                searchVC.suggestionTable.alpha = pct
                
                searchVC.locationLabel.scale = pct.lerp(1, self.fontScaledUp)
                searchVC.textView.setScale(
                    pct.lerp(self.fontScaledDown, 1),
                    anchorPoint: offsets.anchor)
                
                searchVC.pageActionView.alpha = self.isExpanding ? 1 : 0
                searchVC.shadowView.alpha = self.isExpanding ? 1 : 0
                
//                searchVC.textViewFill.backgroundColor = self.isExpanding ? fieldColor : .clear
                searchVC.scrim.alpha = self.isExpanding ? 1 : 0

                searchVC.textView.mask?.frame = self.isExpanding ? maskEndFrame : maskStartFrame

                searchVC.view.layoutIfNeeded()

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

extension UIView {
    func setScale(_ scale: CGFloat, anchorPoint: CGPoint) {
        layer.anchorPoint = anchorPoint
        let scale = scale != 0 ? scale : CGFloat.leastNonzeroMagnitude
        let xPadding = 1 / scale * (anchorPoint.x - 0.5) * bounds.width
        let yPadding = 1 / scale * (anchorPoint.y - 0.5) * bounds.height
        transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xPadding, y: yPadding)
    }
}
