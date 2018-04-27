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
    var targetIndexPath: IndexPath? = nil
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView
        
        let historyVC = (isZoomingIn ? fromVC : toVC) as! HistoryTreeViewController
        let browserVC = (isZoomingIn ? toVC : fromVC) as! BrowserViewController
    
        let pctScaleChange : CGFloat = 120 / browserVC.view.bounds.width
        
        let startScale: CGFloat = isZoomingOut ? 1 : pctScaleChange
        let endScale: CGFloat = isZoomingOut ? pctScaleChange : 1

        let treeStartScale: CGFloat = isZoomingOut ? 1 / pctScaleChange : 1
        let treeEndScale: CGFloat = isZoomingOut ? 1 : 1 / pctScaleChange

        containerView.addSubview(historyVC.view)
        containerView.addSubview(browserVC.view)
        
        let cv = historyVC.collectionView!
        let currentIndexPath = targetIndexPath ?? historyVC.treeMaker.indexPath(for: browserVC.currentTab.currentVisit!)!
        if !isZoomingIn {
            historyVC.centerIndexPath(currentIndexPath)
        }
        
        let expandedCenter = browserVC.view.center
        var zoomedCenter = expandedCenter
        var zoomEndOffset = cv.contentOffset
        if let zoomedAttrs = cv.collectionViewLayout.layoutAttributesForItem(at: currentIndexPath) {
            zoomedCenter = containerView.convert(zoomedAttrs.center, from: cv)
            zoomedCenter.y += 20 // different size statusbar
            
            if isZoomingIn {
                let shiftX = expandedCenter.x - zoomedCenter.x
                let shiftY = expandedCenter.y - zoomedCenter.y
                zoomEndOffset = CGPoint(
                    x: cv.contentOffset.x - shiftX,
                    y: cv.contentOffset.y - shiftY)
            }

        }
        let startOffset = isZoomingIn ? cv.contentOffset : zoomEndOffset
        let endOffset = isZoomingIn ? zoomEndOffset : cv.contentOffset

        let browserScale = Blend(start: startScale, end: endScale) { browserVC.view.scale = $0 }
        let historyScale = Blend(start: treeStartScale, end: treeEndScale) { historyVC.view.scale = $0 }
        let browserCenter = Blend(
            start: isZoomingOut ? expandedCenter : zoomedCenter,
            end: isZoomingOut ? zoomedCenter : expandedCenter) {
            browserVC.view.center = $0
        }
        let alpha = Blend<CGFloat>(start: isZoomingIn ? 0 : 1, end: isZoomingIn ? 1 : 0) {
            browserVC.view.alpha = $0.progress(0, 0.3).clip()
            historyVC.view.alpha = $0.reverse()//.progress(0, 0.3).clip()
        }
        let offset = Blend(start: startOffset, end: endOffset) {
            cv.contentOffset = $0
        }
        
        let spring = SpringSwitch {
            browserCenter.progress = $0
            historyScale.progress = $0
            browserScale.progress = $0
            alpha.progress = $0
            offset.progress = $0
        }
        
        browserVC.contentView.radius = Const.shared.cardRadius
        
        spring.setState(.start)
        let anim = spring.springState(.end) { (_, _) in
            browserVC.contentView.radius = 0
            browserVC.view.center = expandedCenter
            browserVC.view.removeFromSuperview()
            transitionContext.completeTransition(true)
        }
        anim?.springSpeed = 10
        anim?.springBounciness = 3

    }
}
