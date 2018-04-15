//
//  DismissableTabCell.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

typealias CloseTabCallback = (UICollectionViewCell) -> Void

let shadowAlpha : Float = 0.2

class DismissableTabCell: VisitCell, UIGestureRecognizerDelegate {
    var browserTab : Tab?

    @available(iOS 11.0, *)
    override func dragStateDidChange(_ dragState: UICollectionViewCellDragState) {
        if dragState == .dragging {
            layer.borderColor = UIColor.red.cgColor
        }
        else if dragState == .none {
            layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
        addGestureRecognizer(dismissPanner)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTab(_ newTab : Tab?) {
        browserTab = newTab
        guard let visit = browserTab?.currentVisit else { return }
        setVisit(visit)
    }
    
    // only recognize horizontals
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGestureRecognizer.translation(in: superview!)
            if fabs(translation.x) > fabs(translation.y) {
                return true
            }
            return false
        }
        return false
    }
    
    override func select() {
        self.contentView.scale = 0.98
        self.contentView.transform = self.contentView.transform.translatedBy(x: 0, y: -4)
        self.shadowView.scale = 0.98
    }
    
    func refresh() {
        setTab(self.browserTab)
    }
        
    var isDismissing = false
    var startCenter : CGPoint = .zero
    var startAlpha : CGFloat = 0
    
    @objc func panGestureChange(gesture: UIPanGestureRecognizer) {
        let gesturePos = gesture.translation(in: self.superview)

        if gesture.state == .began {
            isDismissing = true
            startCenter = center
            startAlpha = overlay.alpha
        }
        else if gesture.state == .changed {
            if isDismissing {
                let pct = abs(gesturePos.x) / bounds.width
                if pct > 0.4 {
                    overlay.alpha = (pct - 0.4) * 2
                }
                center.x = startCenter.x + elasticLimit(gesturePos.x)
            }
        }
        else if gesture.state == .ended {

            if isDismissing {
                isDismissing = false
                
                let vel = gesture.velocity(in: superview)
                
                var endCenter : CGPoint = startCenter
                var endAlpha : CGFloat = startAlpha
                
                if ( vel.x > 400 || gesturePos.x > bounds.width * 0.5 ) {
                    endCenter.x = startCenter.x + bounds.width
                    endAlpha = 1
                    closeTabCallback(self)
                }
                else if ( vel.x < -400 || gesturePos.x < -bounds.width * 0.5 ) {
                    endCenter.x = startCenter.x - bounds.width
                    endAlpha = 1
                    closeTabCallback(self)
                }
                
                springCenter(to: endCenter, at: vel)
                UIView.animate(withDuration: 0.4) {
                    self.overlay.alpha = endAlpha
                    self.overlay.backgroundColor = .black
                }
            }
        }
    }
}


