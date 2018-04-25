//
//  HistoryZoomAnimatedTransitioning.swift
//  browse
//
//  Created by Evan Brooks on 4/25/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

// TODO: Shouldn't change state permanently here.

class HistoryZoomAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    
    var direction: CustomAnimationDirection!
    var isZoomingOut: Bool { return direction == .present }
    var isZoomingIn: Bool { return direction == .dismiss }
        
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let historyVC = (isZoomingIn ? fromVC : toVC) as! HistoryTreeViewController
        let browserVC = (isZoomingIn ? toVC : fromVC) as! BrowserViewController
    
        let startScale: CGFloat = isZoomingOut ? 1 : 0.3
        let endScale: CGFloat = isZoomingOut ? 0.3 : 1

        let treeStartScale: CGFloat = isZoomingOut ? 3 : 1
        let treeEndScale: CGFloat = isZoomingOut ? 1 : 3

        let browserSnap = browserVC.view.snapshotView(afterScreenUpdates: false)
        containerView.addSubview(historyVC.view)
        if let b = browserSnap { containerView.addSubview(b) }
        
        browserVC.view.isHidden = true
        browserSnap?.scale = startScale
        browserSnap?.springScale(to: endScale)
        
        historyVC.view.scale = treeStartScale
        historyVC.view.springScale(to: treeEndScale ) {_,_ in
            browserVC.view.isHidden = false
            browserSnap?.removeFromSuperview()
            transitionContext.completeTransition(true)
        }
    }
}
